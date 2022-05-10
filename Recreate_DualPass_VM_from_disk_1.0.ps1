 Param (

   [Parameter(Mandatory = $true)] [String] $VmName,
   [Parameter(Mandatory = $true)] [String] $VMRgName,
   [Parameter(Mandatory = $true)] [String] $OSDiskName,
   [Parameter(Mandatory = $true)] [String] $OSDiskRg,
   [Parameter(Mandatory = $true)] [String] $SubscriptionID
  
) 

Write-Host ""
Write-Host "Please use a fresh opened page of Azure Cloud Shell before running the script, since Azure Cloud Shell has a timeout period of 20 minutes of inactivity." -ForegroundColor Yellow
Write-Host "If Azure Cloud Shell times out while running the script, the script will stop at the time of the timeout." -ForegroundColor Yellow
Write-Host "If the script is stopped until it finishes, it might break your VM" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting to write in log file '$HOME/RecreateScript_Execution_log.txt' for troubleshooting purposes"
Start-Transcript -Path "$HOME/RecreateScript_Execution_log.txt" -Append | Out-Null
Write-Host ""

##################################################
#       Connect and  Select subscription:        #
##################################################


#Connect-AzureAD -> Alternative of using method since it does not work on Cloud shell
import-module AzureAD.Standard.Preview
AzureAD.Standard.Preview\Connect-AzureAD -Identity -TenantID $env:ACC_TID 
 
# Connect to Az Account
Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop | Out-Null

#Get current logged in user and active directory tenant details:
Set-AzContext -Subscription $SubscriptionID | Out-Null

$currentSubscription = (Get-AzContext).Subscription.Name
Write-host ""
Write-host "Subscription '$currentSubscription' was selected"


# Start to measure execution time of script
$StartTimeMinute = (Get-Date).Minute
$StartTimeSecond = (Get-Date).Second

#Write-Host "Disabling warning messages to users that the cmdlets used in this script may be changed in the future." -ForegroundColor Yellow
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

Write-host ""
$VmExistsOrDelete = Read-Host "Vm exists (E) or was deleted (D)?"

if ($VmExistsOrDelete -ne "E") # Vm was deleted and will ask if user has exported vm configuration before VM was deleted or stop
{
Write-host ""
$HavePreviousVMConfig = Read-Host "Do you have the previous VM configuration file before VM was deleted (Y) or no VM configuration file exists and script will stop? (S)" 
if ($HavePreviousVMConfig -eq "S") # user does NOT have the previous VM configuration file before VM was deleted
    {
        Write-Host ""
        Write-Host "Without a VM configuration file that was exported before VM was deleted script cannot continue. Script will stop!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host 
        Exit
    }
if ($HavePreviousVMConfig -ne "S") # Testing if the specified disk exists and if yes, user has the previous VM configuration file before VM was deleted and will be ask to select it from the list of existing configuration files
    {
    $error.clear()

        #Test if specified disks exists
        Try { $TestIfDiskExists = Get-AzDisk | ?{$_.Name -eq $OSDiskName} }

        catch {}

        if ($TestIfDiskExists -eq $null)
        {
        Write-Host ""
        Write-Host "Disk '$OSDiskName' was not found in resource group '$VMRgName'" -ForegroundColor Red
        Write-Host ""
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host 
        Write-Host "Script will exit"
        Exit
        }

        # Select an exiting configuration files
        $TempName = "VM_" + "$VmName" + "_Settings"

        Function Show-ExistingVMConfigurationJSONFiles 
        {
        $ErrorActionPreference = 'SilentlyContinue'
        $Menu = 0
        $ExistingVMConfigurationJSONFile = @(Get-ChildItem -path $HOME | ?{$_.Name -like "$TempName*"} | select Name)
        Write-Host ""
        Write-Host "Please select an existing VM Configuration JSON File you want to use:" -ForegroundColor Green;
        % {Write-Host ""}
        $ExistingVMConfigurationJSONFile | % {Write-Host "[$($Menu)]" -ForegroundColor Cyan -NoNewline ; Write-host ". $($_.Name)"; $Menu++; }
        % {Write-Host ""}
        % {Write-Host ""}
        % {Write-Host "[Q]" -ForegroundColor Red -NoNewline ; Write-host ". To quit."}
        % {Write-Host ""}
        $selection = Read-Host "Please select the VM Configuration JSON File Number - Valid numbers are 0 - $($ExistingVMConfigurationJSONFile.count -1), Q to quit"

        If ($selection -eq 'Q') 
            { 
            Clear-Host
            Write-Host ""
            Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
            Write-Host ""
            Stop-Transcript | Out-Null
            Write-host 
            Exit
            }
        
        If ($ExistingVMConfigurationJSONFile.item($selection) -ne $null)

            { 
            Return @{$ExistingVMConfigurationJSONFile = $ExistingVMConfigurationJSONFile[$selection].name;} 
            }
        }
    

        $ExistingVMConfigurationJSONFileSelection = Show-ExistingVMConfigurationJSONFiles
        $NameOfExistingJson = $ExistingVMConfigurationJSONFileSelection.Values
        
        Write-Host ""
        Write-Host "Selected VM Configuration JSON File is: $NameOfExistingJson" -ForegroundColor Green
        $Path_JSON_Vm_Settings = "$HOME/" + "$NameOfExistingJson"
        $json_fullpath = $Path_JSON_Vm_Settings 
    }
}

if ($VmExistsOrDelete -eq "E") # Vm exists and main script will run

{

Write-host ""
Write-host "VM '$VmName' will be deleted and recreated in resource group '$VMRgName' from the specified disk with name '$OSDiskName' from resource group '$OSDiskRg' and at the end will be encrypted again with Dual Pass with same encryption settings" -ForegroundColor Green

##############################################################################
#          Testing if VM and specified disk exist and Get VM object          #
##############################################################################

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
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
Write-host 
Write-Host "Script will exit"
Exit
}
$error.clear()

#Test if specified disks exists
Try { $TestIfDiskExists = Get-AzDisk | ?{$_.Name -eq $OSDiskName} -ErrorAction SilentlyContinue }

catch {}

if ($TestIfDiskExists -eq $null)
{
Write-Host ""
Write-Host "Disk '$OSDiskName' was not found in resource group '$VMRgName'" -ForegroundColor Red
Write-Host ""
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
Write-host 
Write-Host "Script will exit"
Exit
}

#######################################################
#            Exporting VM config to JSON              #
#######################################################


Write-Host ""
Write-Host "Exporting configuration settings for this VM in a JSON file that will be used for the recreate process..."

function ExportVMConfigurationMenu
    {
    param (
        [string]$Title = 'Export VM Configuration Menu'
    )

    Write-Host "========================================================================================== $Title =========================================================================================="
    Write-Host ""
    Write-Host "1: Export a new VM configuration JSON file to HOME Directory" 
    Write-Host ""
    Write-Host "2: Select an existing Vm configuration JSON file from HOME Directory"
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="

   }

 do{
     Write-Host ""
     #call 'ExportVMConfigurationMenu' function
     ExportVMConfigurationMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. A new VM configuration JSON file will be exported to HOME Directory" -ForegroundColor green}
           '2' {Write-host "You chose option #2. Select an existing Vm configuration JSON file from HOME Directory" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq 'q')

   if ($selection -eq "1") # option #1. A new VM configuration JSON file will be exported to HOME Directory
   {
       # Name of the Vm configuration JSON file
        $TimeNow = get-date -f "yyyy-MM-dd_HH:mm:ss"
        $Path_JSON_Vm_Settings = "$HOME/VM_" + "$VmName" + "_Settings_" + "$i" + '_' + "$TimeNow" + ".json"
        $json_fullpath = $Path_JSON_Vm_Settings 

        #export Vm config to JSON
        Get-AzVM -ResourceGroupName $VMRgName -Name $VmName | ConvertTo-Json -depth 100 | Out-file -FilePath $json_fullpath -ErrorAction Stop

        Write-Host ""
        Write-Host "VM configuration JSON file was exported '$json_fullpath'" -ForegroundColor Green
   }

      if ($selection -eq "2") # option #2. Select an existing Vm configuration JSON file from HOME Directory
   {
        $TempName = "VM_" + "$VmName" + "_Settings"

        Function Show-ExistingVMConfigurationJSONFiles 
        {
        $ErrorActionPreference = 'SilentlyContinue'
        $Menu = 0
        $ExistingVMConfigurationJSONFile = @(Get-ChildItem -path $HOME | ?{$_.Name -like "$TempName*"} | select Name)
        Write-Host ""
        Write-Host "Please select an existing VM Configuration JSON File you want to use:" -ForegroundColor Green;
        % {Write-Host ""}
        $ExistingVMConfigurationJSONFile | % {Write-Host "[$($Menu)]" -ForegroundColor Cyan -NoNewline ; Write-host ". $($_.Name)"; $Menu++; }
        % {Write-Host ""}
        % {Write-Host ""}
        % {Write-Host "[Q]" -ForegroundColor Red -NoNewline ; Write-host ". To quit."}
        % {Write-Host ""}
        $selection = Read-Host "Please select the VM Configuration JSON File Number - Valid numbers are 0 - $($ExistingVMConfigurationJSONFile.count -1), Q to quit"

        If ($selection -eq 'Q') 
            { 
            Clear-Host
            Write-Host ""
            Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
            Write-Host ""
            Stop-Transcript | Out-Null
            Write-host 
            Exit
            }
        
        If ($ExistingVMConfigurationJSONFile.item($selection) -ne $null)

            { 
            Return @{$ExistingVMConfigurationJSONFile = $ExistingVMConfigurationJSONFile[$selection].name;} 
            }
        }
    

        $ExistingVMConfigurationJSONFileSelection = Show-ExistingVMConfigurationJSONFiles
        $NameOfExistingJson = $ExistingVMConfigurationJSONFileSelection.Values
        
        Write-Host ""
        Write-Host "Selected VM Configuration JSON File is: $NameOfExistingJson" -ForegroundColor Green
        $Path_JSON_Vm_Settings = "$HOME/" + "$NameOfExistingJson"
        $json_fullpath = $Path_JSON_Vm_Settings 
     }

    if ($selection -eq 'q')

       {
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host 
       Write-Host "Script will exit" -ForegroundColor Green
       Write-Host ""
       exit
       }

}
##################################################################
#   Import JSON file into $import variable  and get AAD App ID   #
##################################################################

$import = Get-Content $json_fullpath -Raw | ConvertFrom-Json -ErrorAction Stop


#Check if we can find AD App ID used in previous encryption process from existing JSON file
$AADClientID = $import.Extensions.Settings.AADClientID

if ($AADClientID -eq $null)
    {$ErrorRetrievingAppID = $true}
            
if ($AADClientID -ne $null)
   {$ErrorRetrievingAppID = $false}


###################################################################################
#       Check if VM is stopped. If not check the VM agent status and stop it      #
###################################################################################

if ($VmExistsOrDelete -eq "E")

{
#Check if VM is stopped. If not, stop it

$provisioningState = (Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -Status -ErrorAction SilentlyContinue).Statuses[1].Code

if ($provisioningState -eq "PowerState/deallocated")
{
    Write-Host ""
    Write-Host "Vm '$VmName' is already stopped" -ForegroundColor Green
}


if ($provisioningState -ne "PowerState/deallocated")
{
    #Check the VM Status  
    $InitialVMagentStatus = (Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -Status -ErrorAction SilentlyContinue).VMagent.Statuses.DisplayStatus

    if ($InitialVMagentStatus -eq "Ready") # 'Ready' state
    {
        Write-Host ""
        Write-Host "Vm Agent is in a '$InitialVMagentStatus' state" -ForegroundColor Green
    }

    if ($InitialVMagentStatus -ne "Ready")  # 'Not Ready' state
    {
        Write-Host ""
        Write-Host "Vm Agent is in a 'Not running' state" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   It is highly recommended that the VM agent is in a 'Ready State', but script will continue to recreate this VM from the specified disk." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   For the encryption process (add ADE extension) to be successful (which happens after this Vm will be deleted and recreated) the VM agent needs to be in a 'Ready' state after Vm will be recreated" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   If VM agent needs is NOT in a 'Ready' state after Vm will be recreated, script will stop and encryption process (add ADE extension) needs to be manually resumed or run again this script once VM is in a 'Ready' state" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Keep in mind that even though after VM will be recreated and the encryption process (add ADE extension) will not be started by the script, VM boot process might be successfully and you may troubleshoot the VM agent issue" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Vm '$VmName' is running" -ForegroundColor Yellow
    Write-Host ""
    $ConfirmationToStop = read-host "To continue Vm needs to be Stopped\Deallocated. Do you want to stop this VM or quit? (S\Q)"
    if ($ConfirmationToStop -eq "Q")
        { 
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host ""
        Exit}
    Elseif ($ConfirmationToStop -ne "Q")
    {
        Write-Host ""
        Write-Host "Stopping VM '$vmName'...";
        Stop-AzVM -Name $vmName -ResourceGroupName $VMRgName -Force | Out-Null
        Write-Host ""
        Write-Host "VM '$vmName' was stopped" -ForegroundColor green
    }
}

}

##################################################################
#       Creating a copy of this disk for backup purposes         #
##################################################################

# creating variable for $NewDiskName and $snapshotName

# Starting number for the copy
$i = 1 

# Name of the snapshot of the disk
$snapshotName = ('snap_' + $i + '_' + $OSDiskName)
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
$snapshotName = ('snap_' + $i + '_' + $OSDiskName)
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
    $snapshotName = ('snap_' + $i + '_' + $OSDiskName)
    
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

#Create snapshot of the OS disk
Write-Host ""
write-host "Creating a copy of the disk '$OSDiskName' for backup purposes..."

$DiskObject = Get-AzDisk | ?{$_.name -eq $OSDiskName}
$DiskId = $DiskObject.id
$DiskLocation = $DiskObject.location
$DiskType = $DiskObject.Sku.Name
$DiskZone = $DiskObject.Zones

# Create snapshot of the specified disk
$snapshotConfig =  New-AzSnapshotConfig -SourceUri $DiskId -Location $DiskLocation -CreateOption copy -SkuName Standard_LRS
New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $OSDiskRg | Out-Null

#####

# Name of the copy of the disk
$NewDiskName = ('copy_' + $i + '_'+ $OSDiskName)
$NewDiskNameLength = $NewDiskName.Length

    If ($NewDiskNameLength -gt "50")
    {
    $NewDiskName = $NewDiskName.Substring(0,$NewDiskName.Length-10)
    }

# check IF Another Copy with the same name exits
$checkIFAnotherCopyIsPresent = Get-AzDisk | ?{$_.Name -eq $NewDiskName} 


if ($checkIFAnotherCopyIsPresent -eq $null) #if a disk with the same name does not exists, use values

{

# Name of the copy of the disk
$NewDiskName = ('copy_' + $i + '_'+ $OSDiskName)
$NewDiskNameLength = $NewDiskName.Length

    If ($NewDiskNameLength -gt "50")
    {
    $NewDiskName = $NewDiskName.Substring(0,$NewDiskName.Length-10)
    }

    Write-Host ""
    Write-Host "A copy of the disk with the name '$NewDiskName' will be created" -ForegroundColor yellow
}

if ($checkIFAnotherCopyIsPresent -ne $null) #if a disk with the same name already exists, add an increment of $i to name of thi disk

{
    do{
    # check if a disk with the same name already exists
    Write-Host ""
    Write-Host "A disk with the same name '$NewDiskName' already exists. Searching for an available name..." -ForegroundColor Yellow
    $i++

    #Create the names of the disk
    $NewDiskName = ('copy_' + $i + '_'+ $OSDiskName)

    # reduce the name of the Disk
    $NewDiskNameLength = $NewDiskName.Length
    If ($NewDiskNameLength -gt "50")
        {
        $NewDiskName = $NewDiskName.Substring(0,$NewDiskName.Length-10)
        }

    # check again if the disks exists with the same name
    $checkIFAnotherCopyIsPresent = Get-AzDisk | ?{$_.Name -eq $NewDiskName}
    }until ($checkIFAnotherCopyIsPresent -eq $null)

    Write-Host ""
    Write-Host "A copy of the disk with the name '$NewDiskName' will be created" -ForegroundColor yellow
}



#Create a managed disk from snapshot
$Snapshot = Get-AzSnapshot -SnapshotName $snapshotName -ResourceGroupName $OSDiskRg

if ($DiskZone -ne $null)
{
    $NewOSDiskConfig = New-AzDiskConfig -AccountType $DiskType -Location $DiskLocation -Zone $DiskZone -CreateOption Copy -SourceResourceId $Snapshot.Id
    #create disk
    $newOSDisk=New-AzDisk -Disk $NewOSDiskConfig -ResourceGroupName $OSDiskRg -DiskName $NewDiskName | Out-Null
    Write-Host ""
    Write-Host "A copy of the disk was created in resource group '$OSDiskRg', in zone '$DiskZone' with name '$NewDiskName'" -ForegroundColor green
}

if ($DiskZone -eq $null)
{
    $NewOSDiskConfig = New-AzDiskConfig -AccountType $DiskType -Location $DiskLocation -CreateOption Copy -SourceResourceId $Snapshot.Id
    #create disk
    $newOSDisk=New-AzDisk -Disk $NewOSDiskConfig -ResourceGroupName $OSDiskRg -DiskName $NewDiskName | Out-Null
    Write-Host ""
    Write-Host "A copy of the disk was created in resource group '$OSDiskRg' with name '$NewDiskName'" -ForegroundColor green
}

#Deleting the snapshot
Write-Host ""
write-host "Deleting unnecessary snapshots created earlier..."
Remove-AzSnapshot -ResourceGroupName $OSDiskRg -SnapshotName $snapshotName -Force | Out-Null


##############################################################
#            Check if disk is attached to a VM or not        #
##############################################################

Write-Host ""
Write-Host "Checking if the disk is attached to a VM"

#check if disk is attached to a vm
$DiskAttachedToVM = (Get-AzDisk -ResourceGroupName $OSDiskRg -DiskName $OSDiskName).ManagedBy

if ($DiskAttachedToVM -ne $null) # if 'ManagedBy' property is not $null, means disk is attached to Vm from 'ManagedBy' property
{


$VmNameWhereDiskIsAttached = $DiskAttachedToVM.Split("/")
$VmNameWhereDiskIsAttached = $VmNameWhereDiskIsAttached[8]

Write-Host ""
Write-Host "Disk '$OSDiskName' is attached to VM '$VmNameWhereDiskIsAttached'" -ForegroundColor Yellow

$VmWhereDiskIsAttachedObject = Get-AzVM | ?{$_.Name -eq $VmNameWhereDiskIsAttached}
$OSDiskOfFoundVM = $VmWhereDiskIsAttachedObject.StorageProfile.OsDisk.Name

function Show-DetachMenu
    {
    param (
        [string]$Title = 'Detach Menu'
    )

    Write-Host "========================================================================================== $Title ==========================================================================================================="
    Write-Host ""
    Write-Host "1: Do you want to detach the disk from Vm if it is attached as a data disk" 
    Write-Host ""
    Write-Host "2: Continue since the disk was already detached or it is an OS disk"
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="

   }

 do{
     Write-Host ""
     #call 'Show-DetachMenu' function
     Show-DetachMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. Disk will be detached" -ForegroundColor green}
           '2' {Write-host "You chose option #2. Continue since the disk was already detached or it is an OS disk" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq 'q')

 if ($selection -eq 'q')

 {
 Write-Host ""
 Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
 Write-Host ""
 Stop-Transcript | Out-Null
 Write-host ""
 Write-Host "Script will exit" -ForegroundColor Green
 Write-Host ""
 exit
 }

    if ($selection -eq "1")

         {

         #check if disk is OS disk or data disk

        if ($OSDiskOfFoundVM -eq $OSDiskName) #disk is OS disk, will not detach and continue
            {
            Write-Host ""
            Write-host "The disk is the OS disk and cannot be detached. Will continue"
            }

         if ($OSDiskOfFoundVM -ne $OSDiskName) # disk is data disk, detaching 
            {
            Write-Host ""
            Write-Host "Detaching disk..."
       

            #Detach disk from VM
            Remove-AzVMDataDisk -DataDiskNames $OSDiskName -VM $VmWhereDiskIsAttachedObject -ErrorAction Stop | Out-Null

            #update VM
            $VmWhereDiskIsAttachedObject | Update-AzVM | Out-Null

            Write-Host ""
            Write-Host "Disk was detached from VM '$VmNameWhereDiskIsAttached'"
            }
        }

        if ($selection -eq "2")
        
         {
        Write-Host ""
        Write-Host "Detach operation will not be performed"

         }
}

if ($DiskAttachedToVM -eq $null)
{
Write-Host ""
Write-Host "Disk is not attached to a VM" -ForegroundColor Green
}



##################################################################
#      Check if VM is encrypted with Dual Pass or not BEK-KEK     #
###################################################################################################################################################################################

$Check_if_VM_Is_Encrypted_with_Dual_Pass = $import.StorageProfile.OsDisk.EncryptionSettings.Enabled
$Check_if_VM_Is_Encrypted_with_Dual_Pass_BEK_KEK = $import.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.keyUrl

if ($Check_if_VM_Is_Encrypted_with_Dual_Pass -eq $null) # Check if VM is encrypted with Dual Pass. If yes, continue, if not, script will stop 
    {
    Write-Host "Vm is not encrypted with Dual Pass. Script will end" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
    Write-Host ""
    Stop-Transcript | Out-Null
    Write-host ""
    Write-Host "Script will exit in 30 seconds"
    Start-Sleep -Seconds 30
    Exit
    }

if ($Check_if_VM_Is_Encrypted_with_Dual_Pass -ne $null -and $Check_if_VM_Is_Encrypted_with_Dual_Pass_BEK_KEK -eq $null) # Check if VM is encrypted with Dual Pass with BEK. If yes, continue, if not, script will stop 
    {
    $EncryptedWithBEK = $true
    Write-host "Checking if VM is encrypted..."
    Write-Host ""
    Write-Host "Vm is encrypted using BEK" -ForegroundColor Green
    Write-Host ""
    }

if ($Check_if_VM_Is_Encrypted_with_Dual_Pass -ne $null -and $Check_if_VM_Is_Encrypted_with_Dual_Pass_BEK_KEK -ne $null) # Check if VM is encrypted with Dual Pass with KEK. If yes, continue, if not, script will stop 
    {
    $EncryptedWithKEK = $true
    Write-host "Checking if VM is encrypted..."
    Write-Host ""
    Write-Host "Vm is encrypted using KEK" -ForegroundColor Green
    Write-Host ""
    }


    
###############################################################################################
#        Get AzureDiskEncryption extension config from file and store them in variables       #
###################################################################################################################################################################################


$SecretUrl = ($import.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SecretUrl).ToLower()
$DiskEncryptionKeyVaultID = ($import.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id).ToLower()
$keyEncryptionKeyUrl = ($import.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.keyurl).ToLower()
$KeyVaultIDforKey = ($import.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.SourceVault.id).ToLower()

$CharArray = $DiskEncryptionKeyVaultID.Split("/")
$diskEncryptionKeyVaultUrlTemp = $CharArray[8]
$diskEncryptionKeyVaultUrl = ("https://" + "$diskEncryptionKeyVaultUrlTemp" + ".vault.azure.net/").ToLower()

 # GET name of Keyvault from JSON section StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
 $Inputstring = $import.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
 $CharArray =$InputString.Split("/")
 $KeyVaultName = $CharArray[8]

if ($EncryptedWithKEK -eq $true)
{
 # GET name of the resource group of Keyvault from JSON section StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
 $Inputstring = $import.StorageProfile.OsDisk.EncryptionSettings.DiskEncryptionKey.SourceVault.Id
 $CharArray =$InputString.Split("/")
 $KVRGname = $CharArray[4]

  #Get the name of the KEK from JSON section StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.keyUrl
 $Inputstring = $import.StorageProfile.OsDisk.EncryptionSettings.KeyEncryptionKey.keyUrl
 $CharArray =$InputString.Split("/")
 $keyEncryptionKeyName = $CharArray[4]
 }

###############################################################################################
#       Menu functions     #
###################################################################################################################################################################################
function Show-Menu
{
    param (
    [string]$Title = 'Azure AD application and Secrets Menu'
    )

    Write-Host ""
    Write-Host "======================================================================================= $Title ======================================================================================"
    Write-Host ""
    Write-Host "1: Enter the existing secret value of the existing secret from AAD App that was found in previous encryption settings with ID: $AADClientID" 
    Write-Host "   Specify the secret value of a secret that was already created in the AAD App that was found and will be used further in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "2: Enter the ID of an existing AAD Application and existing secret value"
    Write-Host "   Specify the ID of an existing AAD Application and existing secret value from the same AAD Application that will used in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "3: Enter the ID of an existing AAD Application ID and a new secret will be created in that application" 
    Write-Host "   A new secret will be created in the AAD App you specify and will used in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "4: Create a new AAD Application ID (AADClientID) and secret" 
    Write-Host "   If the options above are not feasible, you can create a new AAD Application and secret that will be used in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="
}

function Show-Menu2
{
    param (
        [string]$Title = 'For managing encryption keys in the key vault, select an option from below to get the details of an Azure AD application that will be used in authentication process in Azure AD'
    )
    Write-Host ""
    Write-Host "================ $Title ================"
    Write-Host ""
    Write-Host "1: Enter the existing secret value of the existing secret from AAD App that was found in previous encryption settings" -ForegroundColor DarkGray; 
    Write-Host "   Specify the secret value of a secret that was already created in the AAD App that was found and will be used further in the encryption process" -ForegroundColor DarkGray
    Write-Host "   (Option not available since no AAD App was found in previous encryption settings since ADE extension is not installed or AAD App ID is incorrect)" -ForegroundColor red
    Write-Host ""
    Write-Host "2: Enter the ID of an existing AAD Application and existing secret value"
    Write-Host "   Specify the ID of an existing AAD Application and existing secret value from the same AAD Application that will used in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "3: Enter the ID of an existing AAD Application ID and a new secret will be created in that application" 
    Write-Host "   A new secret will be created in the AAD App you specify and will used in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "4: Create a new AAD Application ID (AADClientID) and secret" 
    Write-Host "   If the options above are not feasible, you can create a new AAD Application and secret that will be used in the encryption process" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="
}

function Show-Menu3
{
            param (
            [string]$Title = 'For managing encryption keys in the key vault, select an option from below to get the details of an Azure AD application that will be used in authentication process in Azure AD'
        )

        Write-Host ""
        Write-Host "================ $Title ================"
        Write-Host ""
        Write-Host "1: Enter the existing secret value of the existing secret from AAD App that was found in previous encryption settings" -ForegroundColor DarkGray; 
        Write-Host "   Specify the secret value of a secret that was already created in the AAD App that was found and will be used further in the encryption process" -ForegroundColor DarkGray
        Write-Host "   (Option not available since no AAD App was found in previous encryption settings or is incorrect)" -ForegroundColor red
        Write-Host ""
        Write-Host "2: Enter the ID of an existing AAD Application and existing secret value"
        Write-Host "   Specify the ID of an existing AAD Application and existing secret value from the same AAD Application that will used in the encryption process" -ForegroundColor DarkGray
        Write-Host "   (Option not available since no AAD App was found in previous encryption settings or is incorrect and no AAD application ID was entered)" -ForegroundColor red
        Write-Host ""
        Write-Host "3: Enter the ID of an existing AAD Application ID and a new secret will be created in that application" 
        Write-Host "   A new secret will be created in the AAD App you specify and will used in the encryption process" -ForegroundColor DarkGray
        Write-Host "   (Option not available since no AAD App was found in previous encryption settings or is incorrect and no AAD application ID was entered)" -ForegroundColor red
        Write-Host ""
        Write-Host "4: Create a new AAD Application ID (AADClientID) and secret" 
        Write-Host "   If the options above are not feasible, you can create a new AAD Application and secret that will be used in the encryption process" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Q: Press 'Q' to quit."
        Write-Host ""
        Write-Host "==================================================================================================================================================================================================================="
  
}

function Show-PermissionsMenu
{
  param (
        [string]$Title = 'Permissions Menu'
    )

    Write-Host ""
    Write-Host "============================================================================================= $Title ===================================================================================================="
    Write-Host ""
    Write-Host "1: Permissions will be set automatically as long as your user has access to do this operation" 
    Write-Host ""
    Write-Host "2: Manually give permissions for the AAD Application on keys and secrets from Keyvault: '$keyVaultName' and run again the script"
    Write-Host ""
    Write-Host "3: Confirm that permissions are already set" 
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "==================================================================================================================================================================================================================="
}

function Show-NewAadAppMenu
{
  param (
        [string]$Title = 'Create new AAD Application Menu'
    )

    Write-Host ""
    Write-Host "=========================================================================================== $Title ============================================================================================"
    Write-Host ""
    Write-Host "1: Create a new Azure AD Application and a Secret and give permissions for the APP on keys and secrets from Keyvault: '$keyVaultName'" 
    Write-Host ""
    Write-Host "2: Manually create a new Azure AD Application and Secret and give permissions for the APP on keys and secrets from Keyvault: '$keyVaultName' and run again the script"
    Write-Host ""
    Write-Host "Q: Press 'Q' to quit."
    Write-Host ""
    Write-Host "========================================================================================================================================================================================================================"

}

###############################################################################################
#     Building  Menu      #
###################################################################################################################################################################################

if ($ErrorRetrievingAppID -eq $false) # App ID was retrieved successfully from ADE extension, ask for AAD Client Secret. If cx do not have the secret, it will create a new secret
{

 do{
     
     #call 'Show-Menu' function
     Write-Host "==================================================================================================================================================================================================================="
     Write-host ""
     Write-host "                    For managing encryption keys in the key vault, select an option from below to get the details of an Azure AD application that will be used in authentication process in Azure AD" 
     Show-Menu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. Enter the secret value of the existing secret from exiting AAD App with ID: $AADClientID" -ForegroundColor Green}
           '2' {Write-host "You chose option #2. Enter existing AAD Application ID (AADClientID) and secret value" -ForegroundColor green}
           '3' {Write-host "You chose option #3. Enter the ID of an existing AAD Application ID and a new secret will be created in that application" -ForegroundColor green}
           '4' {Write-host "You chose option #4. We will create a new AAD Application ID (AADClientID) and secret" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq '3' -or $selection -eq '4' -or $selection -eq 'q')
 if ($selection -eq 'q')

 {
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
Write-host ""
 Write-Host "Script will exit" -ForegroundColor Green
 exit
 }
 }

if ($ErrorRetrievingAppID -eq $true) # if App ID cannot be retrieved from ADE extension, ask for AAD Client ID. If cx does not have it, it will create a new AAD application
{

Write-Warning "No Azure disk encryption extension was found installed on VM '$VMName'!"

 do{
     Write-Host ""
     #call 'Show-Menu2' function
     Show-Menu2
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. Enter the secret value of the existing secret from exiting AAD App which is not a valid selection. Make a valid selection. Valid selections are: #2, #3, #4" -ForegroundColor yellow}
           '2' {Write-host "You chose option #2. Enter existing AAD Application ID (AADClientID) and secret value" -ForegroundColor green}
           '3' {Write-host "You chose option #3. Enter the ID of an existing AAD Application ID and a new secret will be created in that application" -ForegroundColor green}
           '4' {Write-host "You chose option #4. We will create a new AAD Application ID (AADClientID) and secret" -ForegroundColor green}
     }

   } until ($selection -eq '2' -or $selection -eq '3' -or $selection -eq '4' -or $selection -eq 'q')


  if ($selection -eq 'q')

 {
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
 Stop-Transcript | Out-Null
 Write-Host ""
 Write-Host "Script will exit" -ForegroundColor Green
 exit
 }

}

if ($NoAppIDorSecretWereSpecified -eq $true)
    {
    
 do{
     Write-Host ""
     #call 'Show-Menu3' function
     Show-Menu3
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. Enter the secret value of the existing secret from exiting AAD App which is not a valid selection. Make a valid selection. Valid selection is: #4" -ForegroundColor yellow}
           '2' {Write-host "You chose option #2. Enter existing AAD Application ID (AADClientID) and secret value which is not a valid selection. Make a valid selection. Valid selection is: #4" -ForegroundColor yellow}
           '3' {Write-host "You chose option #3. Enter the ID of an existing AAD Application ID and a new secret will be created in that application which is not a valid selection. Make a valid selection. Valid selection is: #4" -ForegroundColor yellow}
           '4' {Write-host "You chose option #4. We will create a new AAD Application ID (AADClientID) and secret" -ForegroundColor green}
     }

   } until ($selection -eq '4' -or $selection -eq 'q')


  if ($selection -eq 'q')

 {
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
 Write-Host ""
 Write-Host "Script will exit" -ForegroundColor Green
 exit
 }
 }


###################################################################################################################################################################################
#                                                                                                                                                                                 #
#   Option 1: Enter the existing secret value of the existing secret from AAD App that was found in previous encryption settings with ID: $AADClientID                            #
#   Specify the secret value of a secret that was already created in the AAD App that was found and will be used further in the encryption process                                #
#                                                                                                                                                                                 #
###################################################################################################################################################################################

 if ($selection -eq "1")

 {
    write-host ""
    $aadClientSecretSec = Read-host -Prompt "Enter AAD Client Secret"
    #Get Application ObjectID based on APPID
    $error.clear()
    try {$AppObjectID = (Get-AzureADApplication -Filter "AppId eq '$AADClientID'").ObjectId}

    catch {
    
          }
    if ($error)
    {
    $GetAzureADApplicationObjectIdCommand =  '$AppObjectID' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").ObjectId"
    
    }
 }


###################################################################################################################################################################################
#                                                                                                                                                                                 #
#  Option 2: "Enter the ID of an existing AAD Application and existing secret value"                                                                                              #
#  Specify the ID of an existing AAD Application and existing secret value from the same AAD Application that will used in the encryption process                                 #
#                                                                                                                                                                                 #
###################################################################################################################################################################################

  if ($selection -eq "2")

 {
 Write-Host ""
 $aadClientID = Read-host -Prompt "Enter AAD Client ID"
 Write-Host ""
 $aadClientSecretSec = Read-host -Prompt "Enter AAD Client Secret"
 #Get Application ObjectID based on APPID
 $error.clear()
    try {$AppObjectID = (Get-AzureADApplication -Filter "AppId eq '$AADClientID'").ObjectId}

    catch {
    
          }
    if ($error)
    {
    $GetAzureADApplicationObjectIdCommand =  '$AppObjectID' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").ObjectId"
    
    }

 }

###################################################################################################################################################################################
#                                                                                                                                                                                 #
#  Option 3: "Enter the ID of an existing AAD Application ID and create a new secret in that application"                                                                         #
#  A new secret will be created in the AAD App you specify and will used in the encryption process                                                                                #
#                                                                                                                                                                                 #
###################################################################################################################################################################################

   if ($selection -eq "3")

 {
            write-host ""
            $aadClientID = Read-host -Prompt "Enter AAD Client ID"
            write-host ""
            Write-Host "A new secret will be created" -ForegroundColor "Yellow"

            # Create secret (Azure AD Application Password)

            $startDate = Get-Date
            $endDate = $startDate.AddYears(3)
            write-host ""
            $CustomKeyIdentifier = Read-host -Prompt "Enter AAD Application Secret Display Name"
            #Get Application ObjectID based on APPID
                $error.clear()
            try {$AppObjectID = (Get-AzureADApplication -Filter "AppId eq '$AADClientID'").ObjectId}

            catch {
    
                  }
            if ($error)
            {
            $GetAzureADApplicationObjectIdCommand =  '$AppObjectID' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").ObjectId"
            
            }
           
            #$GetAzureADApplicationObjectIdCommand =  '$AppObjectID' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").ObjectId"
            $aadClientSecret = New-AzureADApplicationPasswordCredential -ObjectId $AppObjectID -CustomKeyIdentifier $CustomKeyIdentifier -StartDate $startDate -EndDate $endDate
            $aadClientSecretSec = $aadClientSecret.Value

            # Output secret to console
             write-host ""
             Write-Host "This is the new Secret. Please save it since you are not able to retrieve it later: $aadClientSecretSec" -ForegroundColor Green
             Write-Host "" 
             Read-host "Press Enter to continue once you saved the Secret" | Out-Null
}

####################################################################################################################################################################################
#                                                                                                                                                                                  #
#  Option 4: "Create a new AAD Application ID (AADClientID) and secret"                                                                                                            #
#  If the options above are not feasible, you can create a new AAD Application and secret that will be used in the encryption process                                              #
#                                                                                                                                                                                  #
####################################################################################################################################################################################

    if ($selection -eq "4")

{

do{
     Write-Host ""
     #call 'Show-NewAadAppMenu' function
     Show-NewAadAppMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. A new Azure AD Application and a Secret will be created and permissions for the APP on keys and secrets from Keyvault: '$keyVaultName' will be set" -ForegroundColor green}
           '2' {Write-host "You chose option #2. You need to create manually a new Azure AD Application and Secret and give permissions for the APP on keys and secrets from Keyvault: '$keyVaultName' and run again the script" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq 'q')


  if ($selection -eq 'q')

    {
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
 Write-Host ""
 Write-Host "Script will exit" -ForegroundColor Green
 exit
    }
 
 if ($selection -eq "1")
        {
         $CxDidNotHadAADClientID = $true
         do {
        #  Create a new AAD Application

         Write-Host ""
         $AzADApplication_DisplayName = Read-host -Prompt "Enter a unique AAD Application Display Name"

         $error.clear()

          try {$AADAppAlreadyExists = Get-AzureADApplication -Filter "DisplayName eq '$AzADApplication_DisplayName'"}

          catch {
    
                }

         if ($error)
             {
              $CheckIfAADAppAlreadyExistsCommand =  '$AADAppAlreadyExists' + " = Get-AzureADApplication -Filter " + '"' + "DisplayName eq " + "'" + "$AzADApplication_DisplayName" + "'" + '"'
    
              }

         $error.clear()
         
         if ($AADAppAlreadyExists -ne $null)
         {
         Write-Host ""
         Write-Host "An AAD Application with this display name already exist!" -ForegroundColor Yellow
         Write-Host ""
         }

         } until ($AADAppAlreadyExists -eq $null)

         $azureAdApplication = New-AzADApplication -DisplayName "$AzADApplication_DisplayName" 

         $error.clear()

         
         try {$servicePrincipal = New-AzADServicePrincipal –ApplicationId $azureAdApplication.AppId -ErrorAction Stop}

         catch {

                Write-Host -Foreground Red -Background Black "An error occurred! Most probably your user does not have proper permissions to create a new AzADServicePrincipal for AAD Application."
                #Write-Host -Foreground Red -Background Black ($Error[0])
                Write-Host ""
              }
        if ($error)
        {
                Write-Host ""
                Write-Host "Manually create a new Azure AD Application and Secret and assign Permissions for this new AppID: $aadClientID on the secret and give permissions for the APP on keys and secrets from Keyvault: '$keyVaultName' and run again the script" -ForegroundColor yellow
                Write-Host ""
                Write-Host "Script will exit"
                Write-Host ""

                $ErrorOutput = Read-host "Do you want to see the error? (Y\N)"
                if ($ErrorOutput -eq "y")
                     {
                     
                     $error

                    # Calculate elapsed time
                    [int]$endMin = (Get-Date).Minute
                    $ElapsedTime =  $([int]$endMin - [int]$startMin)
                    Write-Host ""
                    Write-Host "Script execution time: $ElapsedTime minutes"
                    Write-Host ""
                    Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
                    Write-Host ""
                    Stop-Transcript | Out-Null
                    Write-host ""
                    Write-Host "Script will exit in 30 seconds"
                    Start-Sleep -Seconds 30
                    Stop-Transcript | Out-Null
                    Exit
                    }
                if ( $ErrorOutput -ne "y" )
                    {
                     # Calculate elapsed time
                    [int]$endMin = (Get-Date).Minute
                    $ElapsedTime =  $([int]$endMin - [int]$startMin)
                    Write-Host ""
                    Write-Host "Script execution time: $ElapsedTime minutes"
                    Write-Host ""
                    Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
                    Write-Host ""
                    Stop-Transcript | Out-Null
                    # Calculate elapsed time
                    $EndTimeMinute = (Get-Date).Minute
                    $EndTimeSecond = (Get-Date).Second
                    $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
                    $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
                    $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
                    $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
                    Write-Host ""
                    Write-Host "Script will exit in 30 seconds"
                    Start-Sleep -Seconds 30
                    Exit
                        }
         }

        $servicePrincipalApplicationId = $servicePrincipal.AppId
        $aadClientID = $azureAdApplication.AppId;

        # Create secret (Azure AD Application Password)
 
        $startDate = Get-Date
        $endDate = $startDate.AddYears(3)
        write-host ""
        $CustomKeyIdentifier = Read-host -Prompt "Enter AAD Application Secret Display Name"
        #Get Application ObjectID based on APPID

            $error.clear()
            try {$AppObjectID = (Get-AzureADApplication -Filter "AppId eq '$AADClientID'").ObjectId}

            catch {
    
                  }
            if ($error)
            {
            $GetAzureADApplicationObjectIdCommand =  '$AppObjectID' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").ObjectId"
            
            }
        
        #$GetAzureADApplicationObjectIdCommand =  '$AppObjectID' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").ObjectId"
        $aadClientSecret = New-AzureADApplicationPasswordCredential -ObjectId $AppObjectID -CustomKeyIdentifier $CustomKeyIdentifier -StartDate $startDate -EndDate $endDate
        $aadClientSecretSec = $aadClientSecret.Value


         # Output secret to console

         Write-Host ""
         Write-Host "This is the 'AppID' for the new AD Application: $aadClientID" -ForegroundColor Green
         Write-Host "" 
             # Output secret to console
         Write-Host "This is the 'Secret'. Please save it since you are not able to retrieve it later: $aadClientSecretSec" -ForegroundColor Green
         Write-Host "" 
         Read-host "Press Enter to continue once you saved the Secret" | Out-Null

        }
    

      if ($selection -eq "2")

        {
        Write-Host ""
        Write-Host "Manually create a new Azure AD Application and Secret and assign Permissions for this new AppID: $aadClientID on the secret and give permissions for the APP on keys and secrets from Keyvault: '$keyVaultName' and run again the script" -ForegroundColor yellow

        # Calculate elapsed time
        [int]$endMin = (Get-Date).Minute
        $ElapsedTime =  $([int]$endMin - [int]$startMin)
        Write-Host ""
        Write-Host "Script execution time: $ElapsedTime minutes"

        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit

        }
}
 


#########################################################################################################################################################################################
#                                                           Set permissions for AAD Application to keys and secrets from keyvault                                                       #
#########################################################################################################################################################################################

 # set permissions for AAD Application to keys and secrets from keyvault

 do{
     Write-Host ""
     Write-Host "==================================================================================================================================================================================================================="
     Write-host ""
     Write-host "                                        For managing encryption keys and secrets in the key vault, the Azure AD application needs to have permission on the Key Vault" 
     #call 'Show-PermissionsMenu' function
     Show-PermissionsMenu
     $selection = Read-Host "Please make a selection"
     Write-Host ""
     switch ($selection)
     {
           '1' {Write-host "You chose option #1. Permissions will be set automatically as long as your user has access to do this operation" -ForegroundColor green}
           '2' {Write-host "You chose option #2. Manually give permissions for the AAD Application on keys and secrets from Keyvault: '$keyVaultName' and run again the script" -ForegroundColor green}
           '3' {Write-host "You chose option #3. Confirm that permissions are already set" -ForegroundColor green}
     }

   } until ($selection -eq '1' -or $selection -eq '2' -or $selection -eq '3' -or $selection -eq 'q')
 
 
 if ($selection -eq 'q')

 {
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
 Write-Host ""
# Calculate elapsed time
$EndTimeMinute = (Get-Date).Minute
$EndTimeSecond = (Get-Date).Second
$DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
$DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
$DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
$DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
Write-Host ""
 Write-Host "Script will exit" -ForegroundColor Green
 exit
 }

    if ($selection -eq "1")
{
Write-Host ""

# Check what is the permission model for the Key Vault (Access policy or RBAC)

$AccessPoliciesOrRBAC = (Get-AzKeyVault -VaultName $keyVaultName).EnableRbacAuthorization

# If EnableRbacAuthorization is false, that means the permission model is based on Access Policies and we will attempt to set permissions. If this fails, permissions needs to be granted manually by user.

if ($AccessPoliciesOrRBAC -eq $false)
{
    Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Access policy.'" -ForegroundColor Yellow
    Write-Host ""


#set permissions:
Write-Host "Setting permissions for AppID: $aadClientID on the secret and key from Keyvault '$keyVaultName'..." 

$error.clear()

try {Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys all -PermissionsToSecrets all -ServicePrincipalName $aadClientID -ErrorAction Stop}

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
    Write-Host "Permissions were set for AppID: $aadClientID on the secret and key" -ForegroundColor green
    }

# if there is an error on the set permission operation, permissions were NOT set successfully
if ($error)
    {
    Write-Host ""
    Write-Warning "Permissions could NOT be set for AppID: $aadClientID "
    Write-Host ""
    Write-Host "Manually assign Permissions for this new AppID: $aadClientID on the secret and key from Keyvault '$keyVaultName' and run again the script" -ForegroundColor yellow

        # Calculate elapsed time
        [int]$endMin = (Get-Date).Minute
        $ElapsedTime =  $([int]$endMin - [int]$startMin)
        Write-Host ""
        Write-Host "Script execution time: $ElapsedTime minutes"

        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
         }
}




if ($AccessPoliciesOrRBAC -eq $true)
{
    
    Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Azure role-based access control (RBAC)'." -ForegroundColor Yellow

    # check if AAD Application has at least 'Key Vault Administrator' role assigned or not. IF yes, we skip assigning any other role, if no, assigning "Key Vault Administrator" role for AAD App

    Write-Host ""
    Write-Host "Checking if AAD Application with ID: '$AADClientID' has at least 'Key Vault Administrator' role assigned"
   
        $error.clear()
    try {$AppDisplayName = (Get-AzureADApplication -Filter "AppId eq '$AADClientID'").DisplayName}

    catch {
    
          }
    if ($error)
    {
    $GetAzureADApplicationObjectIdCommand =  '$AppDisplayName' + " = (Get-AzureADApplication -Filter " + '"' + "AppId eq " + "'" + "$AADClientID" + "'" + '"' + ").DisplayName"
    
    }

    # Check if this AAD App has already permissions

    $CheckRoleForApp = Get-AzRoleAssignment -Scope $DiskEncryptionKeyVaultID | ?{$_.RoleDefinitionName -eq "Key Vault Administrator" -and $_.DisplayName -eq $AppDisplayName}

    if ($CheckRoleForApp -ne $null)

     {
     Write-Host ""
     Write-Host "AAD Application with ID: '$AADClientID' has at least 'Key Vault Administrator' role assigned. Skipping assigning any other role." -ForegroundColor Green
     }


    if ($CheckRoleForApp -eq $null) # no permissions found
{
    Write-Host ""
    Write-Host "AAD Application with ID: '$AADClientID' does not have 'Key Vault Administrator' role assigned"
    Write-Host ""
    Write-Host "Assigning 'Key Vault Administrator' role for AppID: $aadClientID on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret

    $error.clear()
    try {
    New-AzRoleAssignment -ApplicationId $aadClientID -RoleDefinitionName "Key Vault Administrator" -Scope $DiskEncryptionKeyVaultID | Out-Null
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
    Write-Host "'Key Vault Administrator' role was assigned for AppID: $aadClientID on Keyvault '$keyVaultName'" -ForegroundColor green
    }

# if there is an error on the set permission operation, permissions were NOT set successfully
if ($error)
    {
    Write-Host ""
    Write-Warning "'Key Vault Administrator' role could not be assigned for AppID: $aadClientID on Keyvault '$keyVaultName'"
    Write-Host ""
    Write-Host "Manually assign 'Key Vault Administrator' role for this new AppID: $aadClientID on Keyvault '$keyVaultName' and run again the script" -ForegroundColor yellow

        # Calculate elapsed time
        [int]$endMin = (Get-Date).Minute
        $ElapsedTime =  $([int]$endMin - [int]$startMin)
        Write-Host ""
        Write-Host "Script execution time: $ElapsedTime minutes"

        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
         # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
         }
}
}
}
    if ($selection -eq "2")
{
        Write-Host ""
        Write-Host "Manually assign Permissions for this new AppID: $aadClientID on the secret and give permissions for the APP on keys and secrets from Keyvault: '$keyVaultName' and run again the script" -ForegroundColor yellow

        # Calculate elapsed time
        [int]$endMin = (Get-Date).Minute
        $ElapsedTime =  $([int]$endMin - [int]$startMin)
        Write-Host ""
        Write-Host "Script execution time: $ElapsedTime minutes"

        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
}
    if ($selection -eq "3")
    {Write-host ""}

########################################################################################
#          Check if encryption settings gathered can successfully encrypt VM           #
###################################################################################################################################################################################

$error.clear()

Write-Host ""
Write-Host "Testing the encryption process for VM with data gathered before deleting VM..." 
Write-Host ""


if ($EncryptedWithBEK -eq $true) # this is a BEK scenario
{

try{
 $sequenceVersion = [Guid]::NewGuid();
 $Test = Set-AzVMDiskEncryptionExtension -ResourceGroupName $VMRgName -VMName $VmName -AadClientID $aadClientID -AadClientSecret $aadClientSecretSec -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -VolumeType "All" –SequenceVersion $sequenceVersion -Force -WhatIf | Out-Null
 Write-Host ""
 }

 catch {
        Write-Host -Foreground Red -Background Black "Errors in the encryption process were found!"
        #Write-Host -Foreground Red -Background Black ($Error[0])
        Write-Host ""
        }

 if ($error)
 {
 Write-host "Please resolve the errors and run again the script." -ForegroundColor Yellow
 Write-Host ""
 $ErrorOutput = Read-host "Do you want to see the error? (Y\N)"
 if ($ErrorOutput -eq "y")
        {
        $error
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host ""
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
        }

 if ($ErrorOutput -eq "n")
        {
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host ""
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
        }
 }
  if (!$error)
 {
 Write-host "NO error was encountered! Proceeding further..." -ForegroundColor green
 Write-Host ""
 }
}


if ($EncryptedWithKEK -eq $true) # this is a KEK scenario
{

try{
 $sequenceVersion = [Guid]::NewGuid();
 $Test = Set-AzVMDiskEncryptionExtension -ResourceGroupName $VMRgName -VMName $VmName -AadClientID $aadClientID -AadClientSecret $aadClientSecretSec -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -KeyEncryptionKeyUrl $keyEncryptionKeyUrl -KeyEncryptionKeyVaultId $KeyVaultIDforKey -VolumeType "All" –SequenceVersion $sequenceVersion -Force -WhatIf | Out-Null
 Write-Host ""
 }

 catch {
        Write-Host -Foreground Red -Background Black "Errors in the encryption process were found!"
        #Write-Host -Foreground Red -Background Black ($Error[0])
        Write-Host ""
        }

 if ($error)
 {
 Write-host "Please resolve the errors and run again the script." -ForegroundColor Yellow
 Write-Host ""
 $ErrorOutput = Read-host "Do you want to see the error? (Y\N)"
 if ($ErrorOutput -eq "y")
        {
        $error
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host ""
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
        }

 if ($ErrorOutput -eq "n")
        {
        Write-Host ""
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-host ""
        # Calculate elapsed time
        $EndTimeMinute = (Get-Date).Minute
        $EndTimeSecond = (Get-Date).Second
        $DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
        $DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
        $DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
        $DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
        Write-Host ""
        Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan
        Write-host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
        }
 }
  if (!$error)
 {
 Write-host "NO error was encountered! Proceeding further..." -ForegroundColor green
 Write-Host ""
 }
}




########################################################################################
#           Check if OS disk and NICs are set to be deleted when VM is deleted         #
###################################################################################################################################################################################

#Check if OS disk is set to be deleted when VM is deleted
$osDiskDeleteOption = $import.StorageProfile.OsDisk.DeleteOption 

if ($osDiskDeleteOption -eq "delete") # if "deleteOption": "Delete", then OS disk is set to be deleted when VM is deleted. Changing "deleteOption" to "Detach"

{
Write-Host "OS disk was set to be deleted when VM is delete!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Disabling this option..."

  Invoke-AzRestMethod `
  -ResourceGroupName $VMRgName `
  -Name $VmName `
  -ResourceProviderName "Microsoft.Compute"  `
  -ResourceType "virtualMachines" `
  -ApiVersion "2021-07-01" `
  -Payload ' { "properties": 
               { 
                 "storageProfile": 
                 {       
                        "osDisk": 
                        {
                          "deleteOption": "Detach", 
                        } 
                 }
               }
             }' `
  -Method 'PATCH' | Out-Null

Write-Host ""
Write-Host "Option was disabled!" -ForegroundColor green
Write-Host ""
}


#Check if NIC is set to be deleted when VM is deleted

$NICDeleteOption = $import.NetworkProfile.NetworkInterfaces.DeleteOption

if ($NICDeleteOption -eq "delete") # if "deleteOption": "Delete", then NIC is set to be deleted when VM is deleted. We cannot change "deleteOption" to "Detach" via script "deleteOption", the cx needs to do it manually.

{

Write-host "Script will stop since NIC is set to be deleted when VM is deleted"
Write-host ""
Write-host "Follow below article to send a PATCH request to change the 'DeleteOption' of NIC from 'delete' to 'detach' and run again the script"
Write-host ""
Write-Host "Article:  https://docs.microsoft.com/en-us/azure/virtual-machines/delete?tabs=powershell2#update-the-delete-behavior-on-an-existing-vm"
Write-Host ""
Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
Write-Host ""
Stop-Transcript | Out-Null
Write-host ""
# Calculate elapsed time
$EndTimeMinute = (Get-Date).Minute
$EndTimeSecond = (Get-Date).Second
$DiffMinutes = ($EndTimeMinute - $StartTimeMinute).ToString()
$DiffSeconds = ($EndTimeSecond - $StartTimeSecond).ToString()
$DiffMinutesEdit = $DiffMinutes -replace "-" -replace ""
$DiffSecondsEdit = $DiffSeconds -replace "-" -replace ""
Write-Host ""
Write-Host "`n`nExecution Time : " $DiffMinutesEdit " Minutes and $DiffSecondsEdit seconds" -BackgroundColor DarkCyan
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
 
}


##############################################################################
#            Prepare variables and VMConfig  for VM Creation VM               #
###################################################################################################################################################################################

# Get variables values from JSON file #

#create variables for redeployment 
$VMRgName = $import.ResourceGroupName; 
$location = $import.Location; 
$vmsize = $import.HardwareProfile.VmSize; 
$VmName = $import.Name; 

#Get plan information from json and create variables
$PlanName = $import.Plan.Name; 
$PlanPublisher = $import.Plan.Publisher; 
$PlanProduct = $import.Plan.Product; 

#Check if VM is in availability set
$AvailabilitySetId = $import.AvailabilitySetReference.id;

#Check if VM is in availability zone
$AvailabilityZone = $import.Zones

#Check if VM is in Proximity placement group (PPG)
$PPGid = $import.ProximityPlacementGroup.id

#A VM can be in an Availability Set and PPG in the same time
if ($AvailabilitySetId -ne $null -and $PPGid -ne $null)
{
$AvailabilitySetName = $AvailabilitySetId.Split('/')[8]
$AvailabilitySetRG = $AvailabilitySetId.Split('/')[4]
$AvailabilitySetId = (Get-AzAvailabilitySet -ResourceGroupName "$AvailabilitySetRG" -Name "$AvailabilitySetName").Id

$PPGName = $PPGid.Split('/')[8]
$PPGRG = $PPGid.Split('/')[4]
$PPGid = (Get-AzProximityPlacementGroup -Name "$PPGName" -ResourceGroupName "$PPGRG").id

#create the vm config
$vmConfig = New-AzVMConfig -VMName $VmName -VMSize $vmsize -AvailabilitySetId "$AvailabilitySetId" -ProximityPlacementGroupId "$PPGid"
}

if ($PPGid -eq $null -and $AvailabilitySetId -ne $null)
{
$AvailabilitySetName = $AvailabilitySetId.Split('/')[8]
$AvailabilitySetRG = $AvailabilitySetId.Split('/')[4]
$AvailabilitySetId = (Get-AzAvailabilitySet -ResourceGroupName "$AvailabilitySetRG" -Name "$AvailabilitySetName").Id

#create the vm config
$vmConfig = New-AzVMConfig -VMName $VmName -VMSize $vmsize -AvailabilitySetId $AvailabilitySetId
}

if ($AvailabilityZone -ne $null)
{
#create the vm config
$vmConfig = New-AzVMConfig -VMName $VmName -VMSize $vmsize -Zone "$AvailabilityZone"
}

if ($PPGid -ne $null -and $AvailabilitySetId -eq $null)
{
$PPGName = $PPGid.Split('/')[8]
$PPGRG = $PPGid.Split('/')[4]
$PPGid = (Get-AzProximityPlacementGroup -Name "$PPGName" -ResourceGroupName "$PPGRG").id
#create the vm config
$vmConfig = New-AzVMConfig -VMName $VmName -VMSize $vmsize -ProximityPlacementGroupId $PPGid
}


if ($AvailabilitySetId -eq $null -and $AvailabilityZone -eq $null -and $PPGid -eq $null)
{
#create the vm config
$vmConfig = New-AzVMConfig -VMName $VmName -VMSize $vmsize -ErrorAction Stop
}


#network card info
$nicIds = $import.NetworkProfile.NetworkInterfaces.Id;
#get ID of primary NIC 
$PrimaryNicId = $nicIds | select-object -first 1 -ErrorAction Stop

#adding the first nic as primary nic to vm config
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $PrimaryNicId -Primary -ErrorAction Stop

#get IDs of secondary NIC(s) 
$SecondaryNicsIds = $nicIds | Select-Object -Skip 1 -ErrorAction Stop

#add all secondary NIC(s) to vmconfig
foreach($SecondaryNicsIds_iterator in $SecondaryNicsIds)
{

$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $SecondaryNicsIds_iterator -ErrorAction Stop

}

#Get OS Disk ID
$OSDiskID = (Get-AzDisk -DiskName $OSDiskName -ResourceGroupName $OSDiskRg).Id


$vmConfig = Set-AzVMOSDisk -VM $vmConfig -ManagedDiskId $OSDiskID -Name $osDiskName -CreateOption attach -Windows -ErrorAction Stop

if ($PlanName -ne $null)
{
Set-AzVMPlan -VM $vmConfig -Publisher $PlanPublisher -Product $PlanProduct -Name $PlanName -ErrorAction Stop
}
###
$Bootdiagnostics = $import.DiagnosticsProfile.BootDiagnostics.StorageUri

if ($Bootdiagnostics -ne $null)
{
$StorageAccountNameTemp = $Bootdiagnostics.Split('/')[2]
$StorageAccountName = $StorageAccountNameTemp.Split('.')[0]
$StorageAccountRG = (Get-AzStorageAccount | ?{$_.StorageAccountName -eq $StorageAccountName}).ResourceGroupName

$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Enable -ResourceGroupName $StorageAccountRG -StorageAccountName $StorageAccountName
}

if ($Bootdiagnostics -eq $null)
{
#Enabling boot diagnostics
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Enable
}

# Check what is the operating system
$WindowsOrLinux = $import.StorageProfile.OsDisk.OsType


if ($WindowsOrLinux -eq "Windows")
{
# Adding data disks:    Note: If we attach data disks to Linux VM in the creation phase, OS will not mount properly data disks and will mess the entire process. Data disks on Linux Vms will be added after Linux VM was created

$DataDisksIDs = $import.StorageProfile.DataDisks.ManagedDisk.id 
$DataDisksLUN = 0

    foreach ($DataDisksIDs_iterator in $DataDisksIDs)
    {
    Add-AzVMDataDisk -VM $vmConfig -ManagedDiskId $DataDisksIDs_iterator -Lun $DataDisksLUN -CreateOption Attach  -ErrorAction Stop | Out-Null
    $DataDisksLUN++
    }

Write-host "The operating system is Windows"
Write-host ""

Set-AzVmOSDisk -VM $vmConfig -ManagedDiskId $OSDiskID -DiskEncryptionKeyUrl $SecretUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -KeyEncryptionKeyUrl $keyEncryptionKeyUrl -KeyEncryptionKeyVaultId $KeyVaultIDforKey -windows -CreateOption Attach -ErrorAction Stop | Out-Null

}


if ($WindowsOrLinux -eq "Linux")
{
$DataDisksIDs = $import.StorageProfile.DataDisks.ManagedDisk.id 
$DataDisksLUN = 0

    foreach ($DataDisksIDs_iterator in $DataDisksIDs)
    {
    Add-AzVMDataDisk -VM $vmConfig -ManagedDiskId $DataDisksIDs_iterator -Lun $DataDisksLUN -CreateOption Attach  -ErrorAction Stop | Out-Null
    $DataDisksLUN++
    }

Write-host "The operating system is Linux"
Write-host ""
Set-AzVmOSDisk -VM $vmConfig -ManagedDiskId $OSDiskID -DiskEncryptionKeyUrl $SecretUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -KeyEncryptionKeyUrl $keyEncryptionKeyUrl -KeyEncryptionKeyVaultId $KeyVaultIDforKey -Linux -CreateOption Attach -ErrorAction Stop | Out-Null

}



##############################################################
#             Detach data disks and  Delete VM               #
###################################################################################################################################################################################

if ($VmExistsOrDelete -eq "E")
{

    $ConfirmationToDeleteVM = read-host "Do you want to proceed with the delete operation for VM '$VMName' (D) or quit (Q)? (D\Q)"
    Write-Host ""
    if ($ConfirmationToDeleteVM -eq "Q")
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
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null 
        Exit}

    if ($ConfirmationToDeleteVM -eq "D")
    {
    
        # First Detach data disks from VM           
        Write-Host "Detaching data disks from VM ..."
        Write-Host ""

        $DataDisksIDs = $import.StorageProfile.DataDisks.ManagedDisk.id

        #storing again Vm into a variable since disks were detached in the meantime
        $vm = Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -ErrorAction Stop

        foreach($DataDisksIDs_iterator in $DataDisksIDs)
            {
             Remove-AzVMDataDisk -VM $vm -ErrorAction Stop | Out-Null
            }

        $vm | Update-AzVM | Out-Null

        # Delete VM
        Write-Host "Deleting VM..." -ForegroundColor Yellow
        Write-Host ""


        Remove-AzVM -ResourceGroupName $VMRgName -Name $VmName -Force -ErrorAction Stop | Out-Null
    }
}

########################################
#             Recreate VM              #
###################################################################################################################################################################################

if ($AvailabilitySetId -ne $null -and $PPGid -ne $null)
{
Write-Host "Recreating VM in Availability Set '$AvailabilitySetName' and in proximity Placement group (PPG) '$PPGName' and attaching data disks..." 
Write-Host 
}

if ($PPGid -eq $null -and $AvailabilitySetId -ne $null)
{
$AvailabilitySetName = $AvailabilitySetId.Split('/')[8]
Write-Host "Recreating VM in Availability Set '$AvailabilitySetName'and attaching data disks..." 
Write-Host 
}

if ($AvailabilityZone -ne $null)
{
Write-Host "Recreating VM in Availability Zone '$AvailabilityZone' and attaching data disks..." 
Write-Host 
}

if ($PPGid -ne $null -and $AvailabilitySetId -eq $null)
{
Write-Host "Recreating VM in proximity Placement group (PPG) '$PPGName' and attaching data disks..." 
Write-Host 
}

if ($AvailabilitySetId -eq $null -and $AvailabilityZone -eq $null -and $PPGid -eq $null)
{
Write-Host "Vm is not apart of an Availability Set, Availability Zone or proximity placement group (PPG)"
Write-Host ""
}

# Creating VM

        Write-Host ""
        Write-Host "==================================================================================================================================================================================================================="
        Write-Host "Encrypting settings used during VM creation:" -ForegroundColor green
        Write-Host ""
        Write-Host "SecretURL: $SecretUrl"
        Write-Host "DiskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl"
        Write-Host "DiskEncryptionKeyVaultId: $DiskEncryptionKeyVaultID"
        Write-Host "keyEncryptionKeyUrl: $keyEncryptionKeyUrl"
        Write-Host "KeyEncryptionKeyVaultId(KeyEncryptionKeyUrl): $KeyVaultIDforKey"
        Write-host "AADClientID is: '$AADClientID'"
        Write-Host "AAD App Secret Value: $aadClientSecretSec"
        Write-Host ""
        Write-Host "==================================================================================================================================================================================================================="
        Write-Host ""

 if ($WindowsOrLinux -eq "Windows")
{
    Write-Host "Recreating VM and attaching data disks..." 
    Write-Host


   # Creating VM. If the create Vm operation (New-AzVm) is taking more than 2 min to return status if Vm was created or not (it can happen if OS does not boot and VM agent not reporting status), will continue
    New-AzVm -ResourceGroupName $VMRgName -Location $location -VM $vmConfig -DisableBginfoExtension -AsJob | Out-Null


    # waiting for the VM state to change to running
    Write-Host "Waiting for VM status to change in 'running'..." # for testing purposes
   do {
       Start-Sleep -Seconds 3
       $VMpowerState = (Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -Status -ErrorAction SilentlyContinue). Statuses[1].DisplayStatus

        }until ($VMpowerState -eq "VM running")
    
    Write-Host ""
    Write-Host "VM was created and is running" -ForegroundColor Green
    Write-Host ""

        # waiting for the VM agent to become ready since encryption will not be able to start without the VM agent in a ready state
        $MinutesToWait = "5"
        $TimeStart = Get-Date
        $TimeEnd = $TimeStart.addminutes($MinutesToWait)
        Write-Host "Waiting for the VM agent to become ready or the script will stop after $MinutesToWait minutes since encryption will not be able to start without the VM agent in a ready state..."
        Write-Host ""

    Do { 
        $TimeNow = Get-Date
        $VMagentStatus = (Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -Status -ErrorAction SilentlyContinue).VMagent.Statuses.DisplayStatus
        Start-Sleep -Seconds 5
        }
        Until ($TimeNow -ge $TimeEnd -or $VMagentStatus -eq "Ready")



    if ($VMagentStatus -ne "Ready")
    {
    Write-host "Script will stop now since VM agent is in a '$VMagentStatus' state and encryption will not be able to start without the VM agent in a 'Ready' state" -ForegroundColor Yellow
    Write-host ""
    Write-host "Check if the operating system booted successfully and resolve this issue if it didn't, or start troubleshooting why the Vm Agent is in a '$VMagentStatus' state" -ForegroundColor Yellow
    Write-host ""
    Write-host "Once the issues listed above were resolved, either run again this script or manually encrypt this VM" -ForegroundColor Yellow
    Write-host ""

    #delete backup disk or keep it
    Write-Host "If not needed, please do not forget to manually delete the copy of the disk that was created in resource group '$OSDiskRg' with name '$NewDiskName'" -ForegroundColor Yellow
    Write-Host ""
    $DeleteCopyOfDisk = Read-Host "Do you want to delete it now? (Y\N)"

    if ($DeleteCopyOfDisk -eq "Y")
    {
        Write-Host ""
        Write-Host "Deleting disk..."
        Remove-AzDisk -ResourceGroupName $OSDiskRg -DiskName $NewDiskName -Force | Out-Null
        Write-Host ""
        Write-Host "Backup Disk was deleted" -ForegroundColor green
    }
        Write-host ""
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
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-Host ""
        Write-host "Script will exit in 10 seconds..."
        Start-Sleep 10
        Exit

    }

}

 if ($WindowsOrLinux -eq "Linux")
{
    Write-Host "Recreating VM and attaching data disks..." 
    Write-Host


   # Creating VM. If the create Vm operation (New-AzVm) is taking more than 2 min to return status if Vm was created or not (it can happen if OS does not boot and VM agent not reporting status), will continue
    New-AzVm -ResourceGroupName $VMRgName -Location $location -VM $vmConfig -AsJob | Out-Null


    # waiting for the VM state to change to running
    Write-Host "Waiting for VM status to change in 'running'..." # for testing purposes
   do {
       Start-Sleep -Seconds 3
       $VMpowerState = (Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -Status -ErrorAction SilentlyContinue). Statuses[1].DisplayStatus

        }until ($VMpowerState -eq "VM running")
    
    Write-Host ""
    Write-Host "VM was created and is running" -ForegroundColor Green
    Write-Host ""

        # waiting for the VM agent to become ready since encryption will not be able to start without the VM agent in a ready state
        $MinutesToWait = "5"
        $TimeStart = Get-Date
        $TimeEnd = $TimeStart.addminutes($MinutesToWait)
        Write-Host "Waiting for the VM agent to become ready or the script will stop after $MinutesToWait minutes since encryption will not be able to start without the VM agent in a ready state..."
        Write-Host ""

    Do { 
        $TimeNow = Get-Date
        $VMagentStatus = (Get-AzVM -ResourceGroupName $VMRgName -Name $VmName -Status -ErrorAction SilentlyContinue).VMagent.Statuses.DisplayStatus
        Start-Sleep -Seconds 5
        }
        Until ($TimeNow -ge $TimeEnd -or $VMagentStatus -eq "Ready")



    if ($VMagentStatus -ne "Ready")
    {
    Write-host "Script will stop now since VM agent is in a '$VMagentStatus' state and encryption will not be able to start without the VM agent in a 'Ready' state" -ForegroundColor Yellow
    Write-host ""
    Write-host "Check if the operating system booted successfully and resolve this issue if it didn't, or start troubleshooting why the Vm Agent is in a '$VMagentStatus' state" -ForegroundColor Yellow
    Write-host ""
    Write-host "Once the issues listed above were resolved, either run again this script or manually encrypt this VM" -ForegroundColor Yellow
    Write-host ""

    #delete backup disk or keep it
    Write-Host "If not needed, please do not forget to manually delete the copy of the disk that was created in resource group '$OSDiskRg' with name '$NewDiskName'" -ForegroundColor Yellow
    Write-Host ""
    $DeleteCopyOfDisk = Read-Host "Do you want to delete it now? (Y\N)"

    if ($DeleteCopyOfDisk -eq "Y")
    {
        Write-Host ""
        Write-Host "Deleting disk..."
        Remove-AzDisk -ResourceGroupName $OSDiskRg -DiskName $NewDiskName -Force | Out-Null
        Write-Host ""
        Write-Host "Backup Disk was deleted" -ForegroundColor green
        Write-host ""
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
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-Host ""
        Write-host "Script will exit in 10 seconds..."
        Start-Sleep 10
        Exit

    }

        if ($DeleteCopyOfDisk -ne "Y")
    {
        Write-host ""
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
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-Host ""
        Write-host "Script will exit in 10 seconds..."
        Start-Sleep 10
        Exit

    }


  }
}


################################################
# Encrypt VM with previous encryption settings #
###################################################################################################################################################################################

Write-Host "Encrypting again VM with previous\gathered encryption settings ..." 
Write-Host 

#>
##########################################################################
#    For VMs Encrypted with Dual Pass (previous version) with BEK\KEK:   #
###################################################################################################################################################################################


if ($Check_if_VM_Is_Encrypted_with_Dual_Pass -ne $null -and $EncryptedWithBEK-eq $true) # Check if VM is encrypted with Dual Pass with BEK. If yes, continue, if not, script will stop 
    {
        Write-Host "VM was Encrypted with Dual Pass (previous version) with BEK"
        Write-Host ""

        #Encrypt the disks of an existing IaaS VM
       
        $sequenceVersion = [Guid]::NewGuid();
        $EncryptionVolumeType = Read-Host -Prompt "Enter the encryption volume type ( OS Disk (OS) \ Data Disks (Data) \ All Disks (all) )"
        Write-Host ""
        Write-Host "Values used for encrypting again VM '$VmName':" -ForegroundColor green
        Write-Host ""
        Write-Host "SecretURL: $SecretUrl"
        Write-Host "DiskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl"
        Write-Host "DiskEncryptionKeyVaultId: $DiskEncryptionKeyVaultID"
        Write-host "AADClientID is: '$AADClientID'"
        Write-Host "AAD App Secret Value: $aadClientSecretSec"
        Write-Host "Encryption Volume Type: $EncryptionVolumeType"
        Write-Host ""
        Write-Host "ADE extension is installing and VM will rebooted. Waiting for VM to come back online..."

         if ($WindowsOrLinux -eq "Windows")
        {
        Write-Host ""
        Write-Host "Windows VM will be Encrypted with Dual Pass (previous version) with BEK..."
        Write-Host ""
        Write-Host "During this process you can verify if the ADE extension status is changing to 'Provisioning succeeded', VM status is 'Running' and try RDP to this VM after 5 minutes in case encryption process becomes a long running operation for some reason (like VM Agent not running), but VM might still be successfully encrypted" -ForegroundColor Yellow
        
        $error.clear()
        try {
        $sequenceVersion = [Guid]::NewGuid();
        Set-AzVMDiskEncryptionExtension -ResourceGroupName $VMRgName -VMName $VmName -AadClientID $aadClientID -AadClientSecret $aadClientSecretSec -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -VolumeType "$EncryptionVolumeType" –SequenceVersion $sequenceVersion -Force | Out-Null
        }

        catch {}

        if ($error) 
            {
            Write-Host ""
            Write-Host "The installation process for ADE extension failed. Vm should have booted correctly. Try to encrypt this VM manually" -ForegroundColor Yellow
            }

        Write-host ""
        Write-host "Vm was encrypted successfully and is up and running!" -ForegroundColor green
        }



        if ($WindowsOrLinux -eq "Linux")
        {
        Write-Host ""
        Write-Host "Linux VM will be Encrypted with Dual Pass (previous version) with BEK..."
        Write-Host ""
        Write-Host "During this process you can verify if the ADE extension status is changing to 'Provisioning succeeded', VM status is 'Running' and try SSH to this VM after 5 minutes in case encryption process becomes a long running operation for some reason (like VM Agent not running), but VM might still be successfully encrypted" -ForegroundColor Yellow
        
        $error.clear()
        Try {
        $sequenceVersion = [Guid]::NewGuid();
        Set-AzVMDiskEncryptionExtension -ResourceGroupName $VMRgName -VMName $VmName -AadClientID $aadClientID -AadClientSecret $aadClientSecretSec -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -VolumeType "$EncryptionVolumeType" –SequenceVersion $sequenceVersion -skipVmBackup -Force | Out-Null
        }

        catch {}

        if ($error) 
            {
            Write-Host ""
            Write-Host "The installation process for ADE extension failed. Vm should have booted correctly. Try to encrypt this VM manually" -ForegroundColor Yellow
            }

        Write-host ""
        Write-host "Vm was encrypted successfully and is up and running!" -ForegroundColor green
        }
    }

if ($Check_if_VM_Is_Encrypted_with_Dual_Pass -ne $null -and $EncryptedWithKEK-eq $true) # Check if VM is encrypted with Dual Pass with KEK. If yes, continue, if not, script will stop 
    {

        #Encrypt the disks of an existing IaaS VM
       
        $EncryptionVolumeType = Read-Host -Prompt "Enter the encryption volume type ( OS Disk (OS) \ Data Disks (Data) \ All Disks (all) )"

        Write-Host ""
        Write-Host "==================================================================================================================================================================================================================="
        Write-Host "Values used for encrypting again VM '$VmName':" -ForegroundColor green
        Write-Host ""
        Write-Host "SecretURL: $SecretUrl"
        Write-Host "DiskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl"
        Write-Host "DiskEncryptionKeyVaultId: $DiskEncryptionKeyVaultID"
        Write-Host "keyEncryptionKeyUrl: $keyEncryptionKeyUrl"
        Write-Host "KeyEncryptionKeyVaultId(KeyEncryptionKeyUrl): $KeyVaultIDforKey"
        Write-host "AADClientID is: '$AADClientID'"
        Write-Host "AAD App Secret Value: $aadClientSecretSec"
        Write-Host "Encryption Volume Type: $EncryptionVolumeType"
        Write-Host ""
        Write-Host "==================================================================================================================================================================================================================="
        Write-Host ""
        Write-Host "ADE extension is installing and VM will rebooted. Waiting for VM to come back online..."



        if ($WindowsOrLinux -eq "Windows")
        {
        Write-Host ""
        Write-Host "Windows VM will be Encrypted with Dual Pass (previous version) with KEK..."
        Write-Host ""
        Write-Host "During this process you can verify if the ADE extension status is changing to 'Provisioning succeeded', VM status is 'Running' and try RDP to this VM after 5 minutes in case encryption process becomes a long running operation for some reason (like VM Agent not running), but VM might still be successfully encrypted" -ForegroundColor Yellow
        
        $error.clear()
        try {
        $sequenceVersion = [Guid]::NewGuid();
        Set-AzVMDiskEncryptionExtension -ResourceGroupName $VMRgName -VMName $VmName -AadClientID $aadClientID -AadClientSecret $aadClientSecretSec -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -KeyEncryptionKeyUrl $keyEncryptionKeyUrl -KeyEncryptionKeyVaultId $KeyVaultIDforKey -VolumeType "$EncryptionVolumeType" –SequenceVersion $sequenceVersion -Force | Out-Null
        }

        catch {}

        if ($error) 
            {
            Write-Host ""
            Write-Host "The installation process for ADE extension failed. Vm should have booted correctly. Try to encrypt this VM manually" -ForegroundColor Yellow
            }

        Write-host ""
        Write-host "Vm was encrypted successfully and is up and running!" -ForegroundColor green
        }



         if ($WindowsOrLinux -eq "Linux")
        {
        Write-Host ""
        Write-Host "Linux VM will be Encrypted with Dual Pass (previous version) with KEK..."
        Write-Host ""
        Write-Host "During this process you can verify if the ADE extension status is changing to 'Provisioning succeeded', VM status is 'Running' and try SSH to this VM after 5 minutes in case encryption process becomes a long running operation for some reason (like VM Agent not running), but VM might still be successfully encrypted" -ForegroundColor Yellow
        
        $error.clear()
        try{
        $sequenceVersion = [Guid]::NewGuid();
        Set-AzVMDiskEncryptionExtension -ResourceGroupName $VMRgName -VMName $VmName -AadClientID $aadClientID -AadClientSecret $aadClientSecretSec -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $DiskEncryptionKeyVaultID -KeyEncryptionKeyUrl $keyEncryptionKeyUrl -KeyEncryptionKeyVaultId $KeyVaultIDforKey -VolumeType "$EncryptionVolumeType" –SequenceVersion $sequenceVersion -skipVmBackup -Force | Out-Null
        }

        catch {}

        if ($error) 
            {
            Write-Host ""
            Write-Host "The installation process for ADE extension failed. Vm should have booted correctly. Try to encrypt this VM manually" -ForegroundColor Yellow
            }

        Write-host ""
        Write-host "Vm was encrypted successfully and is up and running!" -ForegroundColor green

        }
    }


########################################################################
#   Delete the backup disk that was created before running the script  #
########################################################################

    
Write-Host ""
Write-Host "Once you confirm everything worked as it is expected, please do not forget to manually delete the copy of the disk that was created in resource group '$OSDiskRg' with name '$NewDiskName'" -ForegroundColor Yellow

Write-Host ""
$DeleteCopyOfDisk = Read-Host "Do you want to delete it now? (Y\N)"

if ($DeleteCopyOfDisk -eq "Y")
{
Write-Host ""
Write-Host "Deleting disk..."
Remove-AzDisk -ResourceGroupName $OSDiskRg -DiskName $NewDiskName -Force | Out-Null
Write-Host ""
Write-Host "Backup Disk was deleted" -ForegroundColor green
}

################################################################################################################################
#   Output previous Cache settings for data disks since durning Vm creation, cache setting for all data disks was set to none  #
###################################################################################################################################################################################

Write-host ""
Write-host "Host cache was set to none for all data disks" -ForegroundColor Yellow
Write-host ""

 $DataDisksPreviousCacheSettingsOutput = Read-host "Do you want to see the previous cache settings for all data disks to set the cache manually? (Y\N)"
 if ($DataDisksPreviousCacheSettingsOutput -eq "y")
        {
        Write-host ""
        Write-host "Caching options: None = 0, Read = 1, Read\Write = 2. Check the 'caching' property in the Data disk(s) settings stored and listed below:" -ForegroundColor Yellow
        Write-Host ""
        $import.StorageProfile.DataDisks

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
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
        }

 if ($DataDisksPreviousCacheSettingsOutput -eq "n")
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
        Write-Host "Log file '$HOME/RecreateScript_Execution_log.txt' was successfully saved"
        Write-Host ""
        Stop-Transcript | Out-Null
        Write-Host ""
        Write-Host "Script will exit in 30 seconds"
        Start-Sleep -Seconds 30
        Exit
        }
