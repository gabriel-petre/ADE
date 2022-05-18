 Param (

   [Parameter(Mandatory = $true)] [String] $VmName,
   [Parameter(Mandatory = $true)] [String] $VMRgName,
   [Parameter(Mandatory = $true)] [String] $RescueVmName,
   [Parameter(Mandatory = $true)] [String] $RescueVmRg,
   [Parameter(Mandatory = $true)] [String] $CopyDiskName,
   [Parameter(Mandatory = $true)] [String] $RescueVmUserName,
   [Parameter(Mandatory = $true)] [String] $RescueVmPassword,
   [Parameter(Mandatory = $true)] [String] $SubscriptionID,
   [Parameter(Mandatory = $false)] [switch] $associatepublicip,
   [Parameter(Mandatory = $false)] [switch] $enablenested
  
) 
# Keep alive Azure Cloud shell session for at least 20 minutes which is the default timeout period
(' watch -n 10 keep_alive_session') > keepsessionalive.sh
(./keepsessionalive.sh&) | Out-Null

# Start to measure execution time of script
$StartTimeMinute = (Get-Date).Minute
$StartTimeSecond = (Get-Date).Second

Write-Host ""
Write-Warning "Please use a fresh opened page of Azure Cloud Shell before running the script, since Azure Cloud Shell has a timeout period."
Write-Warning "If Azure Cloud Shell times out while running the script, the script will stop at the time of the timeout."
Write-Host ""
Write-Host "Starting to write in log file '$HOME/CreateRescueVMScript_Execution_log.txt' for troubleshooting purposes"
Start-Transcript -Path "$HOME/CreateRescueVMScript_Execution_log.txt" -Append | Out-Null
Write-Host ""

#Write-Host "Disabling warning messages to users that the cmdlets used in this script may be changed in the future." -ForegroundColor Yellow
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Connect to Az Account
Connect-AzAccount -UseDeviceAuthentication

#######################################
#         Select subscription:        #
#######################################


#Get current logged in user and active directory tenant details:
Set-AzContext -Subscription $SubscriptionID | Out-Null
$ctx = Get-AzContext;
$adTenant = $ctx.Tenant.Id;
$currentUser = $ctx.Account.Id

$currentSubscription = (Get-AzContext).Subscription.Name
Write-host "Subscription '$currentSubscription' was selected" -ForegroundColor green
write-host ""

######################################################
#          Testing if VM exist and get variables     #
######################################################

#VM object
$error.clear()
#Test if specified VM exists and also storing VM object in $vm variable
Try {$vm = Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -ErrorAction SilentlyContinue}

catch {}

if ($error)
{
    Write-Host ""
    Write-Host "VM '$VmName' was not found in resource group '$VMRgName'" -ForegroundColor Red
    Write-Host ""
    Write-Host ""
    Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
    Write-Host ""
    Stop-Transcript | Out-Null
    Write-host 
    Write-Host "Script will exit"
    Exit
}
$error.clear()

if($null -eq $vm.StorageProfile.OsDisk.Vhd) #if this is null, then the disk is Managed
{
# Get Keyvault Name from secret URL
$vm = Get-AzVm -ResourceGroupName $VMRgName -Name $vmName
$OSDiskName = $vm.StorageProfile.OsDisk.Name 
$OSDisk = Get-AzDisk | ?{($_.ManagedBy -eq $vm.id) -and ($_.name -eq $OSDiskName)}
$secretUrl = $OSDisk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SecretUrl
$secretUri = [System.Uri] $secretUrl;
$keyVaultName = $secretUri.Host.Split('.')[0];
}

if($null -ne $vm.StorageProfile.OsDisk.Vhd) #if this is NOT null, then the disk is Unmanaged
{
$secretUrl = $VM.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SecretUrl
$secretUri = [System.Uri] $secretUrl;
$keyVaultName = $secretUri.Host.Split('.')[0];
}


######################################################
#      Check Permissions on secrets and keys        #
######################################################


# Check what is the permission model for the Key Vault (Access policy or RBAC)

$AccessPoliciesOrRBAC = (Get-AzKeyVault -VaultName $keyVaultName).EnableRbacAuthorization

# If EnableRbacAuthorization is false, that means the permission model is based on Access Policies and we will attempt to set permissions. If this fails, permissions needs to be granted manually by user.

if ($AccessPoliciesOrRBAC -eq $false)
{
    Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Access policy.'" -ForegroundColor Yellow
    Write-Host ""

#set permissions:
Write-Host "Setting permission for user: $currentUser on the secret and the key from Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret

$error.clear()

try {Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys all -PermissionsToSecrets all -UserPrincipalName $currentUser -ErrorAction Stop}

catch {

  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""
    }

# if there is not error on the set permission operation, permissions were set successfully
if (!$error)
    {
    Write-Host ""
    Write-Host "Permissions were set for user: $currentUser on the secret and key" -ForegroundColor green
    }

# if there is an error on the set permission operation, permissions were NOT set successfully
if ($error)
    {
    Write-Host ""
    Write-Warning "Permissions could NOT be set for user: $currentUser"
    Write-Host ""
    Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow

    # Get Object Id of your Azure AD user
    Write-Host ""
    Write-Host "Conclusion: Your user does not have access to the keys and secrets from Key Vault $keyVaultName and also cannot grant itself permissions" -ForegroundColor yellow
    Write-Host ""
    Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
    Write-Host ""
    Write-Host "If you do not have access to that section, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
    Write-Host ""
    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault $keyVaultName and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
    Write-Host ""
    

    $EnterObjectIDOrStop = read-host "Do you want to try to set permission based on entered ObjectId (O) or stop the script (S)"

    If ($EnterObjectIDOrStop -eq "S" -or $EnterObjectIDOrStop -eq $null)
        {

        # Calculate elapsed time
        [int]$endMin = (Get-Date).Minute
        $ElapsedTime =  $([int]$endMin - [int]$startMin)
        Write-Host ""
        Write-Host "Script execution time: $ElapsedTime minutes"

        Write-Host ""
        Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
        Write-Host ""

        Stop-Transcript | Out-Null

        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
         }

    #clearing $errors variable which contains previous errors:
    $error.clear()

    If ($EnterObjectIDOrStop -eq "O")
        {
          try
        {
        # Get Object Id of your Azure AD user
        Write-Host ""
        $ObjectIdAADUser = read-host "Type the object ID of your Azure AD user"
        Write-Host ""
        Write-Host "Setting KeyVault Access Policy to grant permissions to secrets and keys for AAD user with ID: $ObjectIdAADUser" -ForegroundColor Yellow
        Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys all -PermissionsToSecrets all -objectId $ObjectIdAADUser -ErrorAction Stop
        }

    catch {
      Write-Host ""
      Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
      Write-Host -Foreground Red -Background Black ($Error[0])
      
        }
    }

    if (!$error)
    {
        Write-Host ""
        Write-Host "Permissions were set for user: $currentUser on Keyvault '$keyVaultName'. Verify them also from  azure portal" -ForegroundColor green
        
    }

    if ($error)
    {
    Write-Host ""
    Write-Warning "Permissions could NOT be set for user: $currentUser"
    # Calculate elapsed time
    $EndTimeMinute = (Get-Date).Minute
    $EndTimeSecond = (Get-Date).Second
    $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
    $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
    $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
    $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
    Write-Host ""
    Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan

    Write-Host ""
    Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
    Write-Host ""

    Stop-Transcript | Out-Null

    Write-Host "Script will exit in 30 seconds"
    Start-Sleep -Seconds 30
    Exit
    }
    }
}


#If EnableRbacAuthorization is true, that means the permission model is based on RBAC and we will not attempt to set permissions. Permissions needs to be granted manually by user.

if ($AccessPoliciesOrRBAC -eq $true)
{
    
    Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Azure role-based access control (RBAC)'." -ForegroundColor Yellow
    Write-Host ""

    #check if user already has this role assigned
    Write-Host "Checking if user: $currentUser has the role 'Key Vault Administrator' on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret
    $KeyVaultScope = $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
    $UserHasRoleKeyVaultAdministrator = Get-AzRoleAssignment -Scope $KeyVaultScope | ?{($_.RoleDefinitionName -eq "Key Vault Administrator") -and ($_.SignInName -eq $currentUser) }
    Write-Host ""

    if ($UserHasRoleKeyVaultAdministrator -eq $null)
    {
    #set permissions:
    Write-Host "User: $currentUser does not have the role 'Key Vault Administrator' on Keyvault '$keyVaultName'"
    Write-Host ""
    Write-Host "Assigning 'Key Vault Administrator' role for user: $currentUser on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret

    $error.clear()
    try {
    $KeyVaultScope = $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
    New-AzRoleAssignment -SignInName $currentUser -RoleDefinitionName "Key Vault Administrator" -Scope $KeyVaultScope | Out-Null
    }
catch {

  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""
}

# if there is not error on the set permission operation, permissions were set successfully
if (!$error)
    {
    Write-Host ""
    Write-Host "'Key Vault Administrator' role was assigned for user: $currentUser on Keyvault '$keyVaultName'" -ForegroundColor green
    }

# if there is an error on the set permission operation, permissions were NOT set successfully
if ($error)
    {
    Write-Host ""
    Write-Warning "'Key Vault Administrator' role could not be assigned for user: $currentUser on Keyvault '$keyVaultName'"
    Write-Host ""
    Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow

    # Get Object Id of your Azure AD user
    Write-Host ""
    Write-Host "Conclusion: Your user does not have access to the keys and secrets from Key Vault $keyVaultName and also cannot grant itself permissions" -ForegroundColor yellow
    Write-Host ""
    Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
    Write-Host ""
    Write-Host "If you do not have access to that section, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
    Write-Host ""
    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault $keyVaultName and assign 'Key Vault Administrator' role for your user and then run again the script" -ForegroundColor yellow
    Write-Host ""
    

    $EnterObjectIDOrStop = read-host "Do you want to try to set permission based on entered ObjectId (O) or stop the script (S)"

    If ($EnterObjectIDOrStop -eq "S" -or $EnterObjectIDOrStop -eq $null)
        {

        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan

        Write-Host ""
        Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
        Write-Host ""

        Stop-Transcript | Out-Null

        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
         }

    #clearing $errors variable which contains previous errors:
    $error.clear()

    If ($EnterObjectIDOrStop -eq "O")
        {
          try
        {
        # Get Object Id of your Azure AD user
        Write-Host ""
        $ObjectIdAADUser = read-host "Type the object ID of your Azure AD user"
        Write-Host "" 
        Write-Host "Setting 'Key Vault Administrator' role for user with ID: $ObjectIdAADUser on Keyvault '$keyVaultName'..." -ForegroundColor Yellow
        $KeyVaultScope = $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
        New-AzRoleAssignment -ObjectId $ObjectIdAADUser -RoleDefinitionName "Key Vault Administrator" -Scope $KeyVaultScope | Out-Null
       
        }

    catch {
      Write-Host ""
      Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
      Write-Host -Foreground Red -Background Black ($Error[0])
      
        }
    }

    if (!$error)
    {
    Write-Host ""
    Write-Host "'Key Vault Administrator' role was assigned for user: $currentUser on Keyvault '$keyVaultName'" -ForegroundColor green
        
    }

    if ($error)
    {
    Write-Host ""
    Write-Warning "'Key Vault Administrator' role could not be assigned for user: $currentUser on Keyvault '$keyVaultName'"
    # Calculate elapsed time

    # Calculate elapsed time
    $EndTimeMinute = (Get-Date).Minute
    $EndTimeSecond = (Get-Date).Second
    $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
    $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
    $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
    $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
    Write-Host ""
    Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan

    Write-Host ""
    Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
    Write-Host ""

    Stop-Transcript | Out-Null

    Write-Host "Script will exit in 30 seconds"
    Start-Sleep -Seconds 30
    Exit
    }
    }
    }

        if ($UserHasRoleKeyVaultAdministrator -ne $null)
    {
    Write-host "User: $currentUser is 'Key Vault Administrator' on Keyvault '$keyVaultName'" -ForegroundColor Green
    }
}



#######################################
#      Check if VM is encrypted:      #
#######################################


#get secret url to see if it is null or contains settings.

$SecretURL= $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SecretUrl 

#$SecretURL is $null, there are no encryption settings on this VM, script will stop. If $SecretURL is NOT $null VM has encryption settings in the VM model and continue.

if ($SecretURL -eq $null) #
{
        Write-host "No encryption settings were found from the selected VM for the encrypted disk" -ForegroundColor Red
        write-host ""
        Write-host "Key Vault name: $keyVaultNameTemp" -ForegroundColor Red
        Write-host "Secret Name: $secretNameTemp" -ForegroundColor Red
        Write-host "Secret URI: $secretUrl" -ForegroundColor Red
        Write-host "Secret Version: $secretVersionTemp" -ForegroundColor Red
        Write-host "KEK URL: $KeKUrl" -ForegroundColor Red
        write-host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
}


##########################################################################
#         VM is encrypted with BEK -  Output encryption settings         #
##########################################################################


#get KeyUrl to see if it is null or contains settings.

$KeyUrlTemp = $vm.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.KeyUrl 


#$KeyUrlTemp is $null, there are no KEY encryption settings on this VM. That means this VM is encrypted only with BEK. 

If ($KeyUrlTemp -eq $null) 
{
        Write-Host""
        Write-Host "####################################"
        Write-Host "# This VM is encrypted using a BEK #" -ForegroundColor Green

        #Store encryption settings into variables and list them:

        $EncryptionSettingsAreEnabled = $vm.StorageProfile.OsDisk.EncryptionSettings.Enabled 
        $SecretURL= $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SecretUrl 
        $SourceVaultID = $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id 
        Write-Host "##################################################################################################################################################"
        Write-Host ""
        Write-Host "Encryption Settings for the selected VM are:" -ForegroundColor Green
        Write-Host ""
        Write-Host "Encryption Settings are Enabled: $EncryptionSettingsAreEnabled"
        Write-Host "SecretUrl: $SecretURL"
        Write-Host "SourceVault ID: $SourceVaultID" 
        Write-Host ""
        Write-Host "##################################################################################################################################################"

}


##########################################################################
#         VM is encrypted with KEK -  Output encryption settings         #
##########################################################################


#$KeyUrlTemp is NOT $null. That means this VM is encrypted only with KEK. 

If ($KeyUrlTemp -ne $null) 
{
        Write-Host""
        Write-Host "####################################"
        Write-Host "# This VM is encrypted using a KEK #" -ForegroundColor Green

        #Store encryption settings into variables and list them:

        $EncryptionSettingsAreEnabled = $vm.StorageProfile.OsDisk.EncryptionSettings.Enabled 
        $SecretURL= $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SecretUrl 
        $SourceVaultID = $vm.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id 
        $KeyEncryptionKeySourceVaultId = $vm.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.SourceVault.id 
        $KeyUrl = $vm.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.KeyUrl 
        Write-Host "##################################################################################################################################################"
        Write-Host ""
        Write-Host "Encryption Settings for the selected VM are:" -ForegroundColor Green
        Write-Host ""
        Write-Host "Encryption Settings are Enabled: $EncryptionSettingsAreEnabled"
        Write-Host "SecretUrl: $SecretURL"
        Write-Host "SourceVault ID: $SourceVaultID" 
        Write-Host "KeyEncryptionKey (KEK) SourceVault ID: $KeyEncryptionKeySourceVaultId"
        Write-Host "KeyUrl: $KeyUrl"
        Write-Host ""
        Write-Host "##################################################################################################################################################"

}


##################################################################################################################
#           Create RG for rescue VM, snapshot of encrypted VM, disk from snapshot and delete snapshot            #
##################################################################################################################

#Create the rescue resource group
Write-Host ""
write-host "Creating resource group '$RescueVmRg' if it does not exist..."
Write-Host ""

$location = $vm.Location
$error.clear()
try {Get-AzResourceGroup -Name $RescueVmRg -Location $location -ErrorAction SilentlyContinue | Out-Null}
Catch{

    }

    if ($error)
    {
    Write-Host "Resource group '$RescueVmRg' does not exist. Creating it..."
    New-AzResourceGroup -Name $RescueVmRg -Location $location | Out-Null
    }

    if (!$error)
    {
    Write-Host "Resource group '$RescueVmRg' already exist and will be used for storing dependencies for the Rescue VM."
    }

if($null -eq $vm.StorageProfile.OsDisk.Vhd) #if this is null, then the disk is Managed
{
Write-Host ""
Write-Host "VM '$VmName' has managed disks" -ForegroundColor Green
#Create snapshot of the OS disk
Write-Host ""
write-host "Creating snapshot of the OS disk of VM '$VmName'..."
$DiskName = $vm.StorageProfile.OsDisk.Name
$diskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
$location = $vm.Location
$snapshotConfig =  New-AzSnapshotConfig -SourceUri $diskId -Location $location -CreateOption copy -SkuName Standard_LRS

# Starting number for the copy
$i = 1 

# Name of the snapshot of the disk
$snapshotName = ('snap_' + $i + '_' + $DiskName)
$snapshotNameLength = $snapshotName.Length

    If ($snapshotNameLength -gt "50")
    {
    $snapshotName = $snapshotName.Substring(0,$snapshotName.Length-20)
    }

$checkIFAnotherSnapIsPresent = Get-AzSnapshot | ?{$_.Name -eq $snapshotName}

####
if ($checkIFAnotherSnapIsPresent -eq $null) #if a snapshot with the same name does not exists, use values

{
# Name of the snapshot of the disk
$snapshotName = ('snap_' + $i + '_' + $DiskName)
$snapshotNameLength = $snapshotName.Length

    If ($snapshotNameLength -gt "50")
    {
    $snapshotName = $snapshotName.Substring(0,$snapshotName.Length-20)
    }

    Write-Host ""
    Write-Host "A snapshot of the disk with the name '$snapshotName' will be created" -ForegroundColor green
}


if ($checkIFAnotherSnapIsPresent -ne $null) #if a snapshot with the same name already exists, add an increment of $i to name of the snapshot

{
    do{
    # check if a snapshot with the same name already exists
    Write-Host ""
    Write-Host "A snapshot with the same name '$snapshotName' already exists. Searching for an available name..." -ForegroundColor Yellow
    $i++

    #Create the names of the snapshot
    $snapshotName = ('snap_' + $i + '_' + $DiskName)
    
    # reduce the name of the snapshot
    $snapshotNameLength = $snapshotName.Length
    If ($snapshotNameLength -gt "50")
    {
    $snapshotName = $snapshotName.Substring(0,$snapshotName.Length-20)
    }

    # check again if the snapshot exists with the same name
    $checkIFAnotherSnapIsPresent = Get-AzSnapshot | ?{$_.Name -eq $snapshotName}
    }until ($checkIFAnotherSnapIsPresent -eq $null)

    Write-Host ""
    Write-Host "A snapshot of the disk with the name '$snapshotName' will be created" -ForegroundColor green
}


# Creating snapshot
New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $RescueVmRg | Out-Null

#Create a managed disk from snapshot
$Osdisk = Get-AzDisk | ?{($_.ManagedBy -eq $vm.id) -and ($_.name -eq $OSDiskName)}
$OsdiskRg = $Osdisk.ResourceGroupName
$OsdiskType = $Osdisk.Sku.Name
$Snapshot = Get-AzSnapshot -SnapshotName $snapshotName -ResourceGroupName $RescueVmRg

# Name of the copy of the disk


# check IF Another Copy fo the disk with the same name already exists
$checkIFAnotherCopyIsPresent = Get-AzDisk | ?{$_.Name -eq $CopyDiskName} 

if ($checkIFAnotherCopyIsPresent -eq $null) #if a disk with the same name does not exists, use values

{

# Name of the copy of the disk
$CopyDiskNameLength = $CopyDiskName.Length

    If ($CopyDiskNameLength -gt "50")
    {
    Write-Host ""
    Write-Host "The number of characters is greater than 50. The name will be truncated"
    $CopyDiskName = $CopyDiskName.Substring(0,$CopyDiskName.Length-10)
    }

    Write-Host ""
    Write-Host "A copy of the disk with the name '$CopyDiskName' will be created" -ForegroundColor yellow
}

if ($checkIFAnotherCopyIsPresent -ne $null) #if a disk with the same name already exists, ask for a new name

{
    do{
    # check if a disk with the same name already exists
    Write-Host ""
    Write-Host "A disk with the same name '$CopyDiskName' already exists!" -ForegroundColor Yellow

    $CopyDiskName = Read-Host "Enter a different name for the copy of the disk"

    # reduce the name of the Disk
    $CopyDiskNameLength = $CopyDiskName.Length
    If ($CopyDiskNameLength -gt "50")
        {
        Write-Host ""
        Write-Host "The number of characters is greater than 50. The name will be truncated"
        $CopyDiskName = $CopyDiskName.Substring(0,$CopyDiskName.Length-10)
        }

    # check again if the disks exists with the same name
    $checkIFAnotherCopyIsPresent = Get-AzDisk | ?{$_.Name -eq $CopyDiskName}
    }until ($checkIFAnotherCopyIsPresent -eq $null)

    Write-Host ""
    Write-Host "A copy of the disk with the name '$CopyDiskName' will be created" -ForegroundColor yellow
}


#checking if original OS disk was placed in a specific zone
$OsdiskZone = $Osdisk.Zones

if ($OsdiskZone -ne $null)
{
Write-Host ""
write-host "Creating a managed disk in zone '$OsdiskZone' from snapshot of the OS disk of VM '$VmName'..."
$NewOSDiskConfig = New-AzDiskConfig -AccountType $OsdiskType -Location $Location -Zone $OsdiskZone -CreateOption Copy -SourceResourceId $Snapshot.Id
#create disk
$newOSDisk=New-AzDisk -Disk $NewOSDiskConfig -ResourceGroupName $RescueVmRg -DiskName $CopyDiskName | Out-Null
Write-Host ""
Write-Host "A copy of the disk with the name '$CopyDiskName' was created in zone '$OsdiskZone' from snapshot of the OS disk of VM '$VmName'" -ForegroundColor green
}

if ($OsdiskZone -eq $null)
{
Write-Host ""
write-host "Creating a managed disk from snapshot of the OS disk of VM '$VmName'..."
$NewOSDiskConfig = New-AzDiskConfig -AccountType $OsdiskType -Location $Location -CreateOption Copy -SourceResourceId $Snapshot.Id
#create disk
$newOSDisk=New-AzDisk -Disk $NewOSDiskConfig -ResourceGroupName $RescueVmRg -DiskName $CopyDiskName | Out-Null
Write-Host ""
Write-Host "A copy of the disk with the name '$CopyDiskName' was created from snapshot of the OS disk of VM '$VmName'" -ForegroundColor green
}

#Deleting the snapshot
Write-Host ""
write-host "Deleting the snapshot of the OS disk of VM: '$VmName'"
Remove-AzSnapshot -ResourceGroupName $RescueVmRg -SnapshotName $snapshotName -Force | Out-Null

#Remove the encryption settings from the disk and attach it to the rescue vm using the PowerShell commands
Write-Host ""
Write-host "Removing encryption settings for the copy of the disk that was created"
New-AzDiskUpdateConfig -EncryptionSettingsEnabled $false |Update-AzDisk -diskName $CopyDiskName -ResourceGroupName $RescueVmRg | Out-Null
}

if($null -ne $vm.StorageProfile.OsDisk.Vhd) #if this is NOT null, then the disk is Unmanaged
{

Write-Host ""
Write-Host "VM '$VmName' has unmanaged disks" -ForegroundColor Green
############################ Create a copy of the unmanaged disk into the same storage account##########################################

####################################################
#   Get Impacted VM's Storage Account information  #
####################################################

# get OS disk Storage Account Name (source storage account)
$vhdUri = $VM.StorageProfile.OsDisk.Vhd.uri
$StorageAccountName = $vhdUri.Split('/')[2]
$StorageAccountName  = $StorageAccountName.Split('.')[0]

# get OS disk Storage Account Resource group Name (source storage account)
$StorageAccountResourceGroupName = (Get-AzStorageAccount | ?{$_.StorageAccountName -eq $StorageAccountName}).ResourceGroupName

# get OS disk Storage Account Container Name (source storage account)
$Container = $vhdUri.Split('/')[3]

# get OS disk blob name
$OriginalOSblobName = $vhdUri.Split('/')[4]
$CopyDiskblobName = $CopyDiskName

# Storage Account Keys
$StorageKey = Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroupName 

# Storage Account Context
$Context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKey.Value[0]

$blobs = Get-AzStorageBlob -Container $container -Context $context
#Fetch all the Page blobs with extension .vhd as only Page blobs can be attached as disk to Azure VMs

# check if the blob name ends with .vhd. If no, add .vhd at the end
if ($CopyDiskblobName.EndsWith('.vhd') -eq $false)
{$CopyDiskblobName = $CopyDiskblobName + '.vhd'}


# check IF Another Copy fo the disk with the same name already exists
$checkIFAnotherCopyIsPresent = $blobs | Where-Object {$_.BlobType -eq 'PageBlob' -and $_.Name -eq $CopyDiskblobName}

if ($checkIFAnotherCopyIsPresent -ne $null) #if a disk with the same name already exists, ask for a new name

{
    do{
    # check if a disk with the same name already exists
    Write-Host ""
    Write-Host "A disk with the same name '$CopyDiskblobName' already exists!" -ForegroundColor Yellow
    Write-Host ""
    $CopyDiskblobName = Read-Host "Enter a different name for the copy of the disk"

    # check if the blob name ends with .vhd. If no, add .vhd at the end
    if ($CopyDiskblobName.EndsWith('.vhd') -eq $false)
    {$CopyDiskblobName = $CopyDiskblobName + '.vhd'}

    # check again if the disks exists with the same name
    $checkIFAnotherCopyIsPresent = $blobs | Where-Object {$_.BlobType -eq 'PageBlob' -and $_.Name -eq $CopyDiskblobName}
    
    }until ($checkIFAnotherCopyIsPresent -eq $null)
}
#Start the copy process
Write-Host ""
Write-Host "Creating a copy of the OS disk..."



$copyOperation = Start-AzStorageBlobCopy -SrcBlob $OriginalOSblobName -SrcContainer $Container -Context $Context -DestBlob $CopyDiskblobName -DestContainer $Container -DestContext $Context | Out-Null
$copyOperation | Get-AzStorageBlobCopyState -WaitForComplete | Out-Null

Write-Host ""
Write-Host "A copy of the OS disk with name '$CopyDiskblobName' was created successfully in '$Container' container in storage account '$StorageAccountName'!" -ForegroundColor Green


# Create a new container for the rescue VM to store its OS disk .vhd
$RescueVMContainer = "rescuevm"

$containerExists = Get-AzStorageContainer -Context $Context -Name $RescueVMContainer -ErrorAction SilentlyContinue

if ($containerExists -eq $null)
{
Write-Host ""
Write-Host "Creating container '$RescueVMContainer' in storage account '$StorageAccountName' where the rescue VM '$RescueVmName' will store the OS disk..."
New-AzStorageContainer -Name $RescueVMContainer -Context $Context | Out-Null
}

if ($containerExists -ne $null)
{
Write-Host ""
Write-Host "Container '$RescueVMContainer' already exists in storage account '$StorageAccountName' and will be used to store the OS disk of VM '$RescueVmName'"
}

}


#######################################
#             Creating VM            #
#######################################


$HostnameRescueVM = $RescueVmName
$HostnameRescueVMLength = $HostnameRescueVM.Length
    If ($HostnameRescueVMLength -gt "15")
    {
    $HostnameRescueVMLength = $HostnameRescueVMLength - 15
    $HostnameRescueVM = $HostnameRescueVM.Substring(0,$HostnameRescueVM.Length-$HostnameRescueVMLength)
    }
$location = $vm.Location
$VMSize = "Standard_D2s_v3"
$password = ConvertTo-SecureString "$RescueVmPassword" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("$RescueVmUserName", $password)
$Vnetname = ("VNET_" + $RescueVmName)
$RGofVNET = "$RescueVmRg"
$subnetName = "default"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$NGSName = ("NSG_" + $RescueVmName)
$RGofNSG = "$RescueVmRg"
$PublicIPName = ("PublicIP_" + $RescueVmName)
$PublicIpRgName = "$RescueVmRg"
$nicName = ("NIC_" + $RescueVmName)
$nicRGName = "$RescueVmRg"

#created config:
$vmConfig = New-AzVMConfig -VMName $RescueVmName -VMSize $VmSize


# Check what is the operating system
$WindowsOrLinux = $vm.StorageProfile.OsDisk.OsType

if ($WindowsOrLinux -eq "Windows")
{
Write-Host ""
Write-Host "Operating system is Windows"

#Set Hostname and Credentials
$VirtualMachine = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName "$HostnameRescueVM" -Credential $Credential -ProvisionVMAgent

#Windows Server 2016
$Win2016DefaultPublisher = "MicrosoftWindowsServer"
$Win2016DefaultOffer = "WindowsServer"
$Win2016DefaultSku = "2016-Datacenter"
$Win2016DefaultVersion = "14393.4350.2104091630" # Tested Versions: "14393.4350.2104091630", "14393.5066.220403"

#Windows Server 2019
$Win2019DefaultPublisher = "MicrosoftWindowsServer"
$Win2019DefaultOffer = "WindowsServer"
$Win2019DefaultSku = "2019-Datacenter"
$Win2019DefaultVersion = "latest"

#Windows Server 2022
$Win2022DefaultPublisher = "MicrosoftWindowsServer"
$Win2022DefaultOffer = "WindowsServer"
$Win2022DefaultSku = "2022-Datacenter"
$Win2022DefaultVersion = "latest"


function DefaultOsWinMenu
    {
    param (
        [string]$Title = 'Image selection Menu for creating Rescue VM'
    )

    Write-Host "========================================================================================== $Title ============================================================================"
    Write-Host ""
    Write-Host "1: Create VM '$RescueVmName' from generation 1 Windows Server 2016 default image" 
    Write-Host ""
    Write-Host "2: Create VM '$RescueVmName' from generation 1 Windows Server 2019 default image"
    Write-Host ""
    Write-Host "3: Create VM '$RescueVmName' from generation 1 Windows Server 2022 default image"
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="

   }

 do{
     Write-Host ""
     #call 'DefaultOsWinMenu' function
     DefaultOsWinMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. VM '$RescueVmName' will be created from generation 1 Windows Server 2016 default image" -ForegroundColor green}
           '2' {Write-host "You chose option #2. VM '$RescueVmName' will be created from generation 1 Windows Server 2019 default image" -ForegroundColor green}
           '3' {Write-host "You chose option #2. VM '$RescueVmName' will be created from generation 1 Windows Server 2022 default image" -ForegroundColor green}

     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq '3' -or $selection -eq 'q')

        if ($selection -eq 'q')

         {
         Write-Host "Script will exit" -ForegroundColor Green
         Write-Host ""
         exit
         }

     if ($selection -eq "1") # Rescue VM will be created from Windows Server 2016 default image

         {

        #Set source Marketplace image Windows Server 2016
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $Win2016DefaultPublisher -Offer $Win2016DefaultOffer -Skus $Win2016DefaultSku -Version $Win2016DefaultVersion

        }

     if ($selection -eq "2") # Rescue VM will be created from Windows Server 2019 default image

         {

        #Set source Marketplace image Windows Server 2019
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $Win2019DefaultPublisher -Offer $Win2019DefaultOffer -Skus $Win2019DefaultSku -Version $Win2019DefaultVersion 
        }

     if ($selection -eq "3") # Rescue VM will be created from Windows Server 2022 default image

         {

        #Set source Marketplace image Windows Server 2022
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $Win2022DefaultPublisher -Offer $Win2022DefaultOffer -Skus $Win2022DefaultSku -Version $Win2022DefaultVersion 
        }

}


if ($WindowsOrLinux -eq "Linux")
{
Write-Host ""
Write-Host "Operating system is Linux"

#Set Hostname and Credentials

$VirtualMachine = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName "$HostnameRescueVM" -Credential $Credential #-PatchMode "Manual"


#Get the PublisherName, Offer and Sku of Broken VM

$BrokenVMPublisher = $vm.StorageProfile.ImageReference.Publisher
$BrokenVMOffer = $vm.StorageProfile.ImageReference.Offer
$BrokenVMSku = $vm.StorageProfile.ImageReference.Sku
#$Version = $vm.StorageProfile.ImageReference.Version
$ExactVersion = $vm.StorageProfile.ImageReference.ExactVersion

#Ubuntu
$UbuntuDefaultPublisher = "Canonical"
$UbuntuDefaultOffer = "UbuntuServer"
$UbuntuDefaultSku = "18.04-LTS"

#RedHat
$RedHatDefaultPublisher = "Redhat"
$RedHatDefaultOffer = "RHEL"
$RedHatDefaultSku = "8.2"

#Suse
$SuseDefaultPublisher = "SUSE"
$SuseDefaultOffer = "sles-15-sp3"
$SuseDefaultSku = "gen1"

#CentOS
$CentOSDefaultPublisher = "OpenLogic"
$CentOSDefaultOffer = "CentOS"
$CentOSDefaultSku = "8_2"


if ($BrokenVMPublisher -eq $null)

{
Write-Host ""
Write-Host "VM '$VmName' was created from a custom image or from a specialized disk" -ForegroundColor Green
Write-Host ""

function DefaultMenu
    {
    param (
        [string]$Title = 'Image selection Menu for creating Rescue VM'
    )

    Write-Host "========================================================================================== $Title ============================================================================"
    Write-Host ""
    Write-Host "1: Create VM '$RescueVmName' from generation 1 Ubuntu default image (Ubuntu 18.04-LTS - latest_version)" 
    Write-Host ""
    Write-Host "2: Create VM '$RescueVmName' from generation 1 RedHat default image (RedHat 8.2 -latest_version)"
    Write-Host ""
    Write-Host "3: Create VM '$RescueVmName' from generation 1 Suse default image (Suse 15.3 SP3 - latest_version)"
    Write-Host ""
    Write-Host "4: Create VM '$RescueVmName' from generation 1 CentOS default image (CentOS 8.2 - latest_version)"
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="

   }

 do{
     Write-Host ""
     #call 'DefaultOsOrMenu' function
     DefaultMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. VM '$RescueVmName' will be created from generation 1 Ubuntu default image (Ubuntu 18.04-LTS - latest_version)" -ForegroundColor green}
           '2' {Write-host "You chose option #2. VM '$RescueVmName' will be created from generation 1 RedHat default image (RedHat 8.2 - latest_version)" -ForegroundColor green}
           '3' {Write-host "You chose option #3. VM '$RescueVmName' will be created from generation 1 Suse default image (Suse 15.3 SP3 - latest_version)" -ForegroundColor green}
           '4' {Write-host "You chose option #4. VM '$RescueVmName' will be created from generation 1 CentOS default image (CentOS 8.2 - latest_version)" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq '3' -or $selection -eq '4' -or $selection -eq 'q')

        if ($selection -eq 'q')

         {
         Write-Host "Script will exit" -ForegroundColor Green
         Write-Host ""
         exit
         }

     if ($selection -eq "1") # Rescue VM will be created from default Ubuntu image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $UbuntuDefaultPublisher -Offer $UbuntuDefaultOffer -Skus $UbuntuDefaultSku -Version latest 
        }

     if ($selection -eq "2") # Rescue VM will be created from default RedHat image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $RedHatDefaultPublisher -Offer $RedHatDefaultOffer -Skus $RedHatDefaultSku -Version latest 
        }

     if ($selection -eq "3") # Rescue VM will be created from default Suse image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $SuseDefaultPublisher -Offer $SuseDefaultOffer -Skus $SuseDefaultSku -Version latest 
        }

     if ($selection -eq "4") # Rescue VM will be created from default CentOS image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $CentOSDefaultPublisher -Offer $CentOSDefaultOffer -Skus $CentOSDefaultSku -Version latest 
        }
}

if ($BrokenVMPublisher -ne $null)

{

Write-Host ""
Write-Host "VM '$VmName' was created from an image from PublisherName '$BrokenVMPublisher', with Offer '$BrokenVMOffer', SKU '$BrokenVMSku' and Version '$ExactVersion'."
Write-Host ""

function DefaultOsOrMenu
    {
    param (
        [string]$Title = 'Image selection Menu'
    )

    Write-Host "========================================================================================== $Title ==================================================================================================="
    Write-Host ""
    Write-Host "1: Create VM '$RescueVmName' from generation 1 Ubuntu default image (Ubuntu 18.04-LTS - latest_version)" 
    Write-Host ""
    Write-Host "2: Create VM '$RescueVmName' from generation 1 RedHat default image (RedHat 8.2 -latest_version)"
    Write-Host ""
    Write-Host "3: Create VM '$RescueVmName' from generation 1 Suse default image (Suse 15.3 SP3 - latest_version)"
    Write-Host ""
    Write-Host "4: Create VM '$RescueVmName' from generation 1 CentOS default image (CentOS 8.2 - latest_version)"
    Write-Host ""
    Write-Host "5: Enter menu to select a different SKU from the same Publisher\Offer as VM '$VmName' which is '$BrokenVMPublisher\$BrokenVMOffer\$ExactVersion'"
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="

   }

 do{
     Write-Host ""
     #call 'DefaultOsOrMenu' function
     DefaultOsOrMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. VM '$RescueVmName' will be created from generation 1 Ubuntu default image (Ubuntu 18.04-LTS - latest_version)" -ForegroundColor green}
           '2' {Write-host "You chose option #2. VM '$RescueVmName' will be created from generation 1 RedHat default image (RedHat 8.2 -latest_version)" -ForegroundColor green}
           '3' {Write-host "You chose option #3. VM '$RescueVmName' will be created from generation 1 Suse default image (Suse 15.3 SP3 - latest_version)" -ForegroundColor green}
           '4' {Write-host "You chose option #4. VM '$RescueVmName' will be created from generation 1 CentOS default image (CentOS 8.2 - latest_version)" -ForegroundColor green}
           '5' {Write-host "You chose option #5. Enter menu to select a different SKU from the same Publisher\Offer as VM '$VmName' which is '$BrokenVMPublisher\$BrokenVMOffer\$ExactVersion'" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq '3' -or $selection -eq '4' -or $selection -eq '5' -or $selection -eq 'q')

        if ($selection -eq 'q')

         {
         Write-Host "Script will exit" -ForegroundColor Green
         Write-Host ""
         exit
         }

     if ($selection -eq "1") # Rescue VM will be created from default Ubuntu image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $UbuntuDefaultPublisher -Offer $UbuntuDefaultOffer -Skus $UbuntuDefaultSku -Version latest 
        }

     if ($selection -eq "2") # Rescue VM will be created from default RedHat image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $RedHatDefaultPublisher -Offer $RedHatDefaultOffer -Skus $RedHatDefaultSku -Version latest 
        }

     if ($selection -eq "3") # Rescue VM will be created from default Suse image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $SuseDefaultPublisher -Offer $SuseDefaultOffer -Skus $SuseDefaultSku -Version latest 
        }

     if ($selection -eq "4") # Rescue VM will be created from default CentOS image

         {

        #Set source Marketplace image
        $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $CentOSDefaultPublisher -Offer $CentOSDefaultOffer -Skus $CentOSDefaultSku -Version latest 
        }


     if ($selection -eq "5") # Rescue VM will be created from selection 

   {

    # Get the PublisherName, Offer and Sku for the Rescue VM creation 

    Function Select-ImageSKU {
    $ErrorActionPreference = 'SilentlyContinue'
    $Menu = 0
    $SKUs = @(Get-AzVMImageSku -Location $location -PublisherName $BrokenVMPublisher -Offer $BrokenVMOffer| select Skus, PublisherName, Offer)
    Write-Host ""
    Write-Host "VM '$VmName' was created from an image from PublisherName '$BrokenVMPublisher', with Offer '$BrokenVMOffer' and SKU '$BrokenVMSku'."
    Write-Host ""
    Write-Host "Please select an option you want to use for creating VM '$RescueVmName':" -ForegroundColor Green;
    % {Write-Host ""}
    $SKUs | % {Write-Host "[$($Menu)]" -ForegroundColor Cyan -NoNewline ; Write-host ". PublisherName: $($_.PublisherName)" -NoNewline; Write-host "   Offer: $($_.Offer)" -NoNewline; Write-host "    SKU: $($_.Skus)"; $Menu++; }
    % {Write-Host ""}
    % {Write-Host ""}
    % {Write-Host "[Q]" -ForegroundColor Red -NoNewline ; Write-host ". To quit."}
    % {Write-Host ""}
    $selection = Read-Host "Please select the SKU Number - Valid numbers are 0 - $($SKUs.count -1), Q to quit"

    If ($selection -eq 'Q') { 
        Clear-Host
        Exit
    }
    If ($SKUs.item($selection) -ne $null)
    { Return @{Skus = $SKUs[$selection].Skus; PublisherName = $SKUs[$selection].PublisherName; Offer = $SKUs[$selection].Offer} 
    }
    }

    $ImageSKUSelection = Select-ImageSKU

    $RescueVMPublisher = $ImageSKUSelection.PublisherName
    $RescueVMOffer = $ImageSKUSelection.offer
    $RescueVMSku = $ImageSKUSelection.Skus

    Write-Host ""
    Write-Host "VM '$RescueVmName' will be created from an image from PublisherName '$RescueVMPublisher', with Offer '$RescueVMOffer', SKU '$RescueVMSku' and 'latest' version"

    #Set source Marketplace image
    $VirtualMachine = Set-AzVMSourceImage -VM $vmConfig -PublisherName $RescueVMPublisher -Offer $RescueVMOffer -Skus $RescueVMSku -Version latest 

}


}

}


Write-Host ""
Write-Host "Creating resources for VM '$RescueVmName'..."

#Create a new Vnet
$Vnet = New-AzVirtualNetwork -ResourceGroupName "$RescueVmRg" -Location $location -Name "$Vnetname" -AddressPrefix $VnetAddressPrefix

#Add a subnet
$subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $SubnetAddressPrefix -VirtualNetwork $Vnet

#Associate the subnet to the virtual network
$Vnet | Set-AzVirtualNetwork | Out-Null
$vnet = Get-AzVirtualNetwork -Name $Vnetname -ResourceGroupName $RescueVmRg

# Check what is the operating system
$WindowsOrLinux = $vm.StorageProfile.OsDisk.OsType

if ($WindowsOrLinux -eq "Windows")
{

#Create a detailed network security group (Allowing port 3389 and 443)
$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$rule2 = New-AzNetworkSecurityRuleConfig -Name web-rule1 -Description "Allow HTTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix AzureCloud -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
$rule3 = New-AzNetworkSecurityRuleConfig -Name web-rule2 -Description "Allow all outbound" -Access Allow -Protocol Tcp -Direction Outbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName "$RescueVmRg" -Location "$location" -Name "$NGSName" -SecurityRules $rule1,$rule2,$rule3
}

if ($WindowsOrLinux -eq "Linux")
{
#Create a detailed network security group (Allowing port 3389 and 443)
$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22
$rule2 = New-AzNetworkSecurityRuleConfig -Name web-rule1 -Description "Allow HTTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix AzureCloud -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
$rule3 = New-AzNetworkSecurityRuleConfig -Name web-rule2 -Description "Allow all outbound" -Access Allow -Protocol Tcp -Direction Outbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName "$RescueVmRg" -Location "$location" -Name "$NGSName" -SecurityRules $rule1,$rule2,$rule3

}

If ($associatepublicip)
{
#Create new Public IP
$PublicIPName = ("PublicIP_" + $RescueVmName)
$pip = New-AzPublicIpAddress -Name $PublicIPName -ResourceGroupName $RescueVmRg -Location $location -AllocationMethod Static
}

#Create new Nic
$nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $nicRGName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

#Add NIC to vmconfig
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

# For Managed disks
if($null -eq $vm.StorageProfile.OsDisk.Vhd) #if this is null, then the disk is Managed
{
Write-Host ""
Write-Host "Creating VM '$RescueVmName' with managed disks..."

#Enabling boot diagnostics
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Enable

#Sets the operating system disk properties on a VM.
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Standard_LRS" -CreateOption FromImage 

#Add existing data disk
$datadisk = Get-AzDisk -ResourceGroupName $RescueVmRg -DiskName $CopyDiskName
$DiskSizeInGB = $datadisk.DiskSizeGB
Add-AzVMDataDisk -VM $VirtualMachine -ManagedDiskId $datadisk.Id -Name $CopyDiskName -Caching None -DiskSizeInGB $DiskSizeInGB -Lun 0 -CreateOption Attach | Out-Null
}

# For UnManaged disks
if($null -ne $vm.StorageProfile.OsDisk.Vhd) #if this is NOT null, then the disk is Unmanaged
{
Write-Host ""
Write-Host "Creating VM '$RescueVmName' with unmanaged disks..."

$RandomNumber = Get-Random -Maximum 10000000000000000
$OSDiskName = $RescueVmName + '_OS_disk_' + $RandomNumber

###### get copy disk URI #####
$CopyDiskURI = "https://" + "$StorageAccountName" + '.blob.core.windows.net/' + "$Container" + '/' + "$CopyDiskblobName"

# add copy of the original OS disk as a data this to the rescue VM
$VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $CopyDiskblobName -VhdUri $CopyDiskURI -Lun 0 -CreateOption attach

# Rescue VM OS Disk setup
$STA = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName
$OSDiskUri = $STA.PrimaryEndpoints.Blob.ToString() + "$RescueVMContainer" + '/' + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption fromImage 
}
 
 if ($WindowsOrLinux -eq "Windows")
{
# Create the VM.
New-AzVM -ResourceGroupName $RescueVmRg -Location $location -VM $VirtualMachine -DisableBginfoExtension | Out-Null
}

if ($WindowsOrLinux -eq "Linux")
{
# Create the VM.
New-AzVM -ResourceGroupName $RescueVmRg -Location $location -VM $VirtualMachine | Out-Null
}

#Wait until VM guest agent becomes ready
do {
Start-Sleep -Seconds 5
$VMagentStatus = (Get-AzVM -ResourceGroupName $RescueVmRg -Name $RescueVmName -Status).VMagent.Statuses.DisplayStatus
} until ($VMagentStatus -eq "Ready")


##############################################################################
#                   Copy encryption settings to the rescue VM                #
##############################################################################

$vm = Get-AzVm -ResourceGroupName $VMRgName -Name $vmName
$RescueVMObject = Get-AzVM -ResourceGroupName $RescueVmRg -Name $RescueVmName

Write-Host ""
Write-Host "Copying encryption settings from VM '$VmName' to VM '$RescueVmName'..."
$RescueVMObject.StorageProfile.OsDisk.EncryptionSettings = $vm.StorageProfile.OsDisk.EncryptionSettings

Write-Host ""
Write-Host "Updating and restarting Rescue VM '$RescueVmName'..."   
$RescueVMObject| Update-AzVM | Out-Null # the update operation will restart VM


#Wait until VM guest agent becomes ready
do {
Start-Sleep -Seconds 5
$VMagentStatus = (Get-AzVM -ResourceGroupName $RescueVmRg -Name $RescueVmName -Status -ErrorAction SilentlyContinue).VMagent.Statuses.DisplayStatus
} until ($VMagentStatus -eq "Ready")


if ($WindowsOrLinux -eq "Windows")
{

#######################################
#          Unlock Process             #
#######################################

Write-Host ""
Write-host "Rescue Vm was successfully created and BEK volume was mounted" -ForegroundColor green

Write-Host ""
Write-host "Unlocking attached disk..."

#######################################################################################
#       Create script that will be sent to Rescue VM with Invoke-AzVMRunCommand       #
#######################################################################################


#Test if script file exists in cloud shell drive

$PathScriptUnlockDisk = "$HOME/Unlock-Disk"
$TestPath = Test-Path -Path $PathScriptUnlockDisk
if($TestPath -eq $true)
{Remove-Item -Path $PathScriptUnlockDisk}


#Creating 'Unlock-Disk' Script

('Start-Transcript -Path "c:\Unlock Disk\Unlock-Script-log.txt" -Append | Out-Null') > $PathScriptUnlockDisk

("get-date") >> $PathScriptUnlockDisk

'[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12' >> $PathScriptUnlockDisk

'Set-ExecutionPolicy -ExecutionPolicy unrestricted -Scope LocalMachine -force' >> $PathScriptUnlockDisk

# Disable Server Manager on startup
( 'Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask >> $path') >> $PathScriptUnlockDisk

( '$DriveToUnlock' + '= (Get-BitLockerVolume | ?{$_.KeyProtector -ne $null}).mountpoint') >> $PathScriptUnlockDisk

( '$BekVolumeDriveLetter' + ' = (Get-Volume -FileSystemLabel "Bek Volume").DriveLetter') >> $PathScriptUnlockDisk

( '$BekPath' + ' = ' + '$BekVolumeDriveLetter' + ' + ":\*"' ) >> $PathScriptUnlockDisk

( '$BekKeyName' + ' = (Get-ChildItem -Path ' + '$BekPath' + ' -Force -Include *.bek).Name') >> $PathScriptUnlockDisk

( '$BekPath' + ' = ' + '$BekVolumeDriveLetter' + ' + ":\" + ' + '$BekKeyName' ) >> $PathScriptUnlockDisk

('manage-bde -unlock ' + '$DriveToUnlock' + ' -recoveryKey ' + '"' + '$BekPath' + '"' ) >> $PathScriptUnlockDisk


# Disable Server Manager on startup
( 'Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask ') >> $PathScriptUnlockDisk

#create unlock script from desktop
('$DesktopUnlockScript' + ' = "C:\Users\Public\Desktop\Unlock disk.ps1"') >> $PathScriptUnlockDisk

('$DesktopUnlockScripttPath' + ' = New-Item "C:\Users\Public\Desktop\Unlock disk.ps1"') >> $PathScriptUnlockDisk


        #check if the BEK disk is offline and put it online

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '#check if the BEK disk is offline and put it online' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '$BEKVolumeNumber' + ' = (get-disk | ?{($_.operationalstatus -eq "Offline") -and ($_.IsSystem -eq ' + '$false' + ' ) -and ($_.size -like "503*") }).Number'  + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'If (' + '$BEKVolumeNumber' + ' -ne ' + '$Null' + ')' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '{ ' + '$error' + '.clear()'  + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ ' # try to bring the disk online. If Vm inside Hyper-V is running command will end with error and write-host to stop VM first ' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'try {' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Set-Disk -number ' + '$BEKVolumeNumber' + ' -IsOffline ' + '$False' + ' -ErrorAction SilentlyContinue' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Write-Host "Setting Bek Volume as online..."}' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'catch {}' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'if (' + '$error' + ')' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '{Write-host "Vm inside Hyper-V is running and it is using Bek Volume. Disk cannot be set as online. Stop Vm inside Hyper-V and run again the script" -ForegroundColor red' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Write-Host "Script will exit in 30 seconds"' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Start-Sleep 30' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'exit' + "'") >> $PathScriptUnlockDisk
  
        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '}' + "'") >> $PathScriptUnlockDisk
      
        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'if (!' + '$error' + ')' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '{Write-host "Bek Volume is online" -ForegroundColor green}' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '}' + "'") >> $PathScriptUnlockDisk
        

         #check if the encrypted disk is offline and put it online

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '#check if the encrypted disk is offline and put it online ' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '$NumberOfEncryptedDisk' + ' = (get-disk | ?{($_.number -gt "0") -and ($_.size -gt "128849018880")}).Number' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'If (' + '$NumberOfEncryptedDisk' + ' -ne ' + '$Null' + ')' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '{' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '$error' + '.clear()' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '# try to bring the disk online. If Vm inside Hyper-V is running command will end with error and write-host to stop VM first' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'try {Set-Disk -number ' + '$NumberOfEncryptedDisk' + ' -IsOffline ' + '$False' + ' -ErrorAction SilentlyContinue' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Write-Host "Setting Encrypted disk as online..."' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '}' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'catch {}' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'if (' + '$error' + ')' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '{Write-host "Vm inside Hyper-V is running and it is using the Encrypted disk. Disk cannot be set as online. Stop Vm inside Hyper-V and run again the script" -ForegroundColor red' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Write-Host "Script will exit in 30 seconds"' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Start-Sleep 30' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'exit' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '}' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'if (!' + '$error' + ')' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '{Write-host "Encrypted disk is online" -ForegroundColor green}' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '}' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ 'Write-Host "Unlocking disk..."' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'"+ '$DriveToUnlock' + '= (Get-BitLockerVolume | ?{$_.KeyProtector -ne $null}).mountpoint' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'" + '$BekVolumeDriveLetter' + ' = (Get-Volume -FileSystemLabel "Bek Volume").DriveLetter' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'" + '$BekPath' + ' = ' + '$BekVolumeDriveLetter' + ' + ":\*"'  + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'" + '$BekKeyName' + ' = (Get-ChildItem -Path ' + '$BekPath' + ' -Force -Include *.bek).Name' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'" + '$BekPath' + ' = ' + '$BekVolumeDriveLetter' + ' + ":\" + ' + '$BekKeyName' + "'") >> $PathScriptUnlockDisk

         ('Add-Content "' + '$DesktopUnlockScripttPath' + '" ' + "'" + 'manage-bde -unlock ' + '$DriveToUnlock' + ' -recoveryKey ' + '"' + '$BekPath' + '"' + "'") >> $PathScriptUnlockDisk


#create unlock script from from startup 
('$UnlockStartupScript' + ' = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Unlock disk.ps1"') >> $PathScriptUnlockDisk

('$UnlockStartupScriptpath' + ' = New-Item "C:\Unlock Disk\Unlock disk.ps1"') >> $PathScriptUnlockDisk


        ('Add-Content "' + '$UnlockStartupScriptpath' + '" ' + "'"+ '$DriveToUnlock' + '= (Get-BitLockerVolume | ?{$_.KeyProtector -ne $null}).mountpoint' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$UnlockStartupScriptpath' + '" ' + "'" + '$BekVolumeDriveLetter' + ' = (Get-Volume -FileSystemLabel "Bek Volume").DriveLetter' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$UnlockStartupScriptpath' + '" ' + "'" + '$BekPath' + ' = ' + '$BekVolumeDriveLetter' + ' + ":\*"'  + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$UnlockStartupScriptpath' + '" ' + "'" + '$BekKeyName' + ' = (Get-ChildItem -Path ' + '$BekPath' + ' -Force -Include *.bek).Name' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "' + '$UnlockStartupScriptpath' + '" ' + "'" + '$BekPath' + ' = ' + '$BekVolumeDriveLetter' + ' + ":\" + ' + '$BekKeyName' + "'") >> $PathScriptUnlockDisk

        ('Add-Content "'+ '$UnlockStartupScriptpath' + '" ' + "'" + 'manage-bde -unlock ' + '$DriveToUnlock' + ' -recoveryKey ' + '"' + '$BekPath' + '"' + "'") >> $PathScriptUnlockDisk


#create bat stored in startup folder for all users, which will call the unlock script from startup folder when user log on and reboot of VM

'#create .bat script stored in startup folder for all users, which will call the unlock script.ps1 when user log on and reboot of VM' >> $PathScriptUnlockDisk
'' >> $PathScriptUnlockDisk

('$StartupFolderAllUsers' + ' = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"') >> $PathScriptUnlockDisk

('$StartupUnlockDiskBatScriptPath' + ' = New-Item ' + '"' + '$StartupFolderAllUsers' + '\unlock_disk.bat' + '"') >> $PathScriptUnlockDisk

#('Add-Content "'+ '$StartupUnlockDiskBatScriptPath' + '"' + " '" + 'msg * ' + '"' + 'Unlocking encrypted disk...If disk does not unlock automaticaly in 30 seconds, use the shortcut from desktop to unlock encrypted attached disk.' + '"' + "'") >> $PathScriptUnlockDisk
('Add-Content "' + '$StartupUnlockDiskBatScriptPath' + '" ' + "'" + 'powershell.exe -windowstyle hidden -File "C:\Unlock Disk\Unlock disk.ps1' + '"' + "'") >> $PathScriptUnlockDisk

('Stop-Transcript | Out-Null') >> $PathScriptUnlockDisk

# Invoke the command on the VM, using the local file
Invoke-AzVMRunCommand -Name $RescueVmName -ResourceGroupName $RescueVmRg -CommandId 'RunPowerShellScript' -ScriptPath $PathScriptUnlockDisk | Out-Null


##################################################################################################################################### 
Write-Host ""
Write-host "Attached disk was successfully unlocked" -ForegroundColor green

If ($enablenested)
{
        #Install-WindowsFeature -Name Hyper-V -ComputerName localhost -IncludeManagementTools

        $PathScriptInstallHyperVRole = "$HOME/Install-Hyper-V-Role"
        $TestPath = Test-Path -Path $PathScriptInstallHyperVRole
        if($TestPath -eq $true)
        {Remove-Item -Path $PathScriptInstallHyperVRole}

        ('Start-Transcript -Path "c:\Unlock Disk\Install-Hyper-V-Role-log.txt" -Append | Out-Null') > $PathScriptInstallHyperVRole
        ('Install-WindowsFeature -Name Hyper-V,DHCP -ComputerName localhost -IncludeManagementTools') >> $PathScriptInstallHyperVRole
        ('Stop-Transcript | Out-Null') >> $PathScriptInstallHyperVRole
         
        Write-Host ""
        Write-Host "Installing Hyper-V and DHCP Roles on Rescue VM..."
        # Invoke the command on the VM, using the local file
        Invoke-AzVMRunCommand -Name $RescueVmName -ResourceGroupName $RescueVmRg -CommandId 'RunPowerShellScript' -ScriptPath $PathScriptInstallHyperVRole | Out-Null   


        #restart VM:

        Write-Host ""
        Write-Host "Restarting Rescue VM..."
        Restart-AzVM -ResourceGroupName $RescueVmRg -Name $RescueVmName | Out-Null   

        # waiting for 20 seconds since after installing the Hyper-V role, Vm might reboot one more time
        Start-Sleep -Seconds 60

        ###############################################

        Write-Host ""
        Write-Host "Configuring and creating VM inside Hyper-V"
        #Creating script to be sent to VM for, initialize BEK, create BEK volume, copy secret in bek Volume, create VM inside Hyper-V

        $PathScriptEnableNested = "$HOME/EnableNested"
        $TestPath = Test-Path -Path $PathScriptEnableNested
        if($TestPath -eq $true)
        {Remove-Item -Path $PathScriptEnableNested}

        #Creating 'EnableNested' Script

        ('Start-Transcript -Path "c:\Unlock Disk\EnableNested-log.txt" -Append | Out-Null') > $PathScriptEnableNested

        ("get-date") >> $PathScriptEnableNested


        # Put the BEK volume disk offline

        ( '# Put the BEK volume disk offline') >> $PathScriptEnableNested

        ( '$BEKVolumeNumber' + ' = (get-disk | ?{($_.operationalstatus -eq "Online") -and ($_.IsSystem -eq ' + '$false' + ') -and ($_.size -like "503*") }).Number') >> $PathScriptEnableNested

        ( 'Set-Disk -number ' + '$BEKVolumeNumber' + ' -IsOffline ' + '$True') >> $PathScriptEnableNested

        
        #Put encrypted disk offline

        ( ' #Put encrypted disk offline') >> $PathScriptEnableNested

        ( '$NumberOfEncryptedDisk' + ' = (get-disk | ?{($_.number -gt "0") -and ($_.size -gt "128849018880")}).Number') >> $PathScriptEnableNested

        ( 'Set-Disk -Number ' + '$NumberOfEncryptedDisk' + ' -IsOffline ' + '$True' +' ') >> $PathScriptEnableNested


        #Create VM in Hyper-V
        ( '#Create VM in Hyper-V') >> $PathScriptEnableNested

        ( '$HypervVMName' + ' = "RescueVM"') >> $PathScriptEnableNested

        ( 'New-VM -Name ' + '$HypervVMName' + ' -Generation 1 -MemoryStartupBytes 4GB -NoVHD') >> $PathScriptEnableNested

        #Removing DVD drive
        ( '#Removing DVD drive') >> $PathScriptEnableNested

        ( 'Remove-VMDvdDrive -VMName ' + '$HypervVMName' + ' -ControllerNumber 1 -ControllerLocation 0') >> $PathScriptEnableNested

        # add disks to Hyper-V VM
        ( '# add disks to Hyper-V VM') >> $PathScriptEnableNested

        ( '$BEKVolumeNumber' + ' = (get-disk | ?{($_.IsSystem -eq ' + '$false' + ') -and ($_.size -like "503*") }).Number') >> $PathScriptEnableNested

        ( 'Get-Disk ' + '$NumberOfEncryptedDisk' + ' | Add-VMHardDiskDrive -VMName ' + '$HypervVMName' + ' -ControllerType IDE -ControllerNumber 0') >> $PathScriptEnableNested

        ( 'Get-Disk ' + '$BEKVolumeNumber' + ' | Add-VMHardDiskDrive -VMName ' + '$HypervVMName' + ' -ControllerType IDE -ControllerNumber 1') >> $PathScriptEnableNested


        #Create a virtual switch that will be used by the nested VMs 
        ('New-VMSwitch -Name "Nested-VMs" -SwitchType Internal') >> $PathScriptEnableNested
        ('New-NetIPAddress -IPAddress 192.168.0.1 -PrefixLength 24 -InterfaceAlias "vEthernet (Nested-VMs)"') >> $PathScriptEnableNested

        #Create a DHCP scope that will be used to automatically assign IP to the nested VMs.
        # Make sure you use a valid DNS server so the VMs can connect to the internet. In this example, we are using 8.8.8.8 which is Googleâ€™s public DNS
        ('Add-DhcpServerV4Scope -Name "Nested-VMs" -StartRange 192.168.0.2 -EndRange 192.168.0.254 -SubnetMask 255.255.255.0') >> $PathScriptEnableNested
        ('Set-DhcpServerV4OptionValue -DnsServer 8.8.8.8 -Router 192.168.0.1') >> $PathScriptEnableNested 

        # allow internet access
        ('New-NetNat -Name Nat_VM -InternalIPInterfaceAddressPrefix 192.168.0.0/24') >> $PathScriptEnableNested

        #Connects the virtual network of Vm in Hyper-V to virtual switch "Nested-VMs".
        ('Get-VM | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "Nested-VMs"') >> $PathScriptEnableNested

        #create .bat script stored in startup folder for all users, which will start_Hyper-V_Manager when a user RDPs
        '#create .bat script stored in startup folder for all users, which will start_Hyper-V_Manager when a user RDPs' >> $PathScriptEnableNested
        '' >> $PathScriptEnableNested

        ('$StartupFolderAllUsers' + ' = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"') >> $PathScriptEnableNested

        ('$StartupUnlockDiskBatScriptPath' + ' = New-Item ' + '"' + '$StartupFolderAllUsers' + '\Start_Hyper-V_Manager.bat' + '"') >> $PathScriptEnableNested

        ('Add-Content "' + '$StartupUnlockDiskBatScriptPath' + '" ' + "'" + 'start Virtmgmt.msc' + "'") >> $PathScriptEnableNested

        ('Stop-Transcript | Out-Null') >> $PathScriptEnableNested

        # Invoke the command on the VM, using the local file
        Invoke-AzVMRunCommand -Name $RescueVmName -ResourceGroupName $RescueVmRg -CommandId 'RunPowerShellScript' -ScriptPath $PathScriptEnableNested | Out-Null 

        Write-Host ""
        Write-host "Hyper-V VM was successfully configured and created" -ForegroundColor green
    }
#>
Write-Host ""
Write-host "Rescue VM was successfully configured and created" -ForegroundColor green

Write-Host ""
Write-host "You can RDP to the Rescue VM"

#removing all necesary script from Azure Cloud Drive

Remove-Item $PathScriptUnlockDisk

If ($enablenested)
{
Remove-Item $PathScriptInstallHyperVRole
Remove-Item $PathScriptEnableNested
}


# Calculate elapsed time
$EndTimeMinute = (Get-Date).Minute
$EndTimeSecond = (Get-Date).Second
$DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
$DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
$DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
$DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
Write-Host ""
Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan

Write-Host ""
Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
Write-Host ""

Stop-Transcript | Out-Null
Write-Host ""
}


if ($WindowsOrLinux -eq "Linux")
{

#######################################
#          Unlock Process             #
#######################################

Write-Host ""
Write-host "Rescue Vm was successfully created and BEK volume was mounted" -ForegroundColor green

Write-Host ""
Write-host "Unlocking attached disk..."

#######################################################################################
#       Create script that will be sent to Rescue VM with Invoke-AzVMRunCommand       #
#######################################################################################


# Downloading the unlock script for Linux VMs in $HOME directory of cloud drive

$ProgressPreference = 'SilentlyContinue'
$PathScriptUnlockAndMountDisk = "$home/linux-mount-encrypted-disk.sh"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/azure-cli-extensions/main/src/vm-repair/azext_vm_repair/scripts/linux-mount-encrypted-disk.sh" -OutFile $PathScriptUnlockAndMountDisk | Out-Null

# Invoke the command on the VM, using the local file
Invoke-AzVMRunCommand -Name $RescueVmName -ResourceGroupName $RescueVmRg -CommandId 'RunShellScript' -ScriptPath $PathScriptUnlockAndMountDisk | Out-Null

Write-Host ""
Write-host "Rescue VM was successfully configured and created" -ForegroundColor green

Write-Host ""
Write-host "You can SSH to the Rescue VM"

#removing all used scripst from Azure Cloud Drive
Remove-Item $PathScriptUnlockAndMountDisk


# Calculate elapsed time
$EndTimeMinute = (Get-Date).Minute
$EndTimeSecond = (Get-Date).Second
$DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
$DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
$DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
$DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
Write-Host ""
Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan

Write-Host ""
Write-Host "Log file '$HOME/CreateRescueVMScript_Execution_log.txt' was successfully saved"
Write-Host ""

Stop-Transcript | Out-Null
Write-Host ""
}
