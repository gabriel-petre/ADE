# wiki for manual process of unlocking the disk: https://supportability.visualstudio.com/AzureVMPOD/_wiki/wikis/AzureVMPOD/266218/Azure_Virtual-Machine_Features_Disk-Encryption_HowTo_Unlock-an-encrypted-disk-V2



<# 
=======================================================================
What this script does: 

1. Checks if prerequisites are installed. If not, it will download and install or making other adjustments for the prerequisites to be met
2. Authenticates you to your selected subscription
3. Unlocks an encypted disk (in all tested scenarios) that is attached to the VM you are running the script, by selecting from the list the Original Encrypted VM name and the coresponding secret for the disk 

=======================================================================
Requirements:

VM from which you are running the script, needs to have internet access

=======================================================================
Limitations:

If your user account is enabled for Azure AD Multi-Factor Authentication, Microsoft doesn't currently support using the Azure Active Directory Module for Windows PowerShell to connect to Azure AD.

To perform administrative tasks by using the Azure Active Directory Module for Windows PowerShell, use either of the following methods:

Disable Azure Active Directory Multi-Factor Authentication for the user account.
Use a different admin account that isn't enabled for Azure Active Directory Multi-Factor Authentication.

Related article: https://docs.microsoft.com/en-us/troubleshoot/azure/active-directory/unable-authenticate-credentials#scenario-2-your-user-account-is-enabled-for-azure-ad-multi-factor-authentication


=======================================================================
Prerequisites:

"NuGet" PackageProvider (MinimumVersion 2.8.5.201)
"Az.Compute" Module (Curent version is 4.17.1)
"Az.Accounts" Module (Curent version is 2.6.0) ->  ADAL way not working anymore. Fortunately since Az.Accounts 2.2.0, there is Get-AzAccessToken which seems to make ADAL entirely unnecessary. Install New Az.Accounts with at least 2.2.0 version. Newest at this point 2.2.3
"Az.Resources" Module (Curent version is 4.4.0)
"Az.KeyVault" Module
.NET Framework (Minimum version 4.7.2)
"Internet explorer enhanced security" needs to be disabled
Working directory: "C:\Unlock Disk"

=======================================================================
Tested Scenarios:

VMs with Managed\Unmanaged Disks:

  Vm encrypted with Single Pass (New Method) with BEK - (OS\Data disks)
  Vm encrypted with Single Pass (New Method) with KEK - (OS\Data disks)

  Vm encrypted with Dual Pass   (Old Method) with BEK - (OS\Data disks)
  Vm encrypted with Dual Pass   (Old Method) with KEK - (OS\Data disks)

  VM Generation 1 and generation 2

=======================================================================

Working Directory: "C:\Unlock Disk"

=======================================================================

Methods to retreive the secret:

1. From existing encrypted VM's disks -> This only works for Single\Dual Pass method
2. From existing encrypted disks      -> This only works for Single Pass method

=======================================================================
#>

#============================================Start of Functions definition================================================


Write-Host "Disabling warning messages to users that the cmdlets used in this script may be changed in the future." -ForegroundColor Yellow
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

function Authentication{

#Login Part:

Write-host ""
Write-host "Login to your Az Account.."
Write-host ""
Login-AzAccount
#Connect-AzAccount -TenantId 72f988bf-86f1-41af-91ab-2d7cd011db47

#Select Azure Subscription
Write-host ""
Write-host "Select Subscription.."
Write-host ""

$subscriptionId = ( Get-AzSubscription | Out-GridView -Title "Select an Azure Subscription ..." -PassThru).SubscriptionId

Set-AzContext -Subscription $subscriptionId | out-null

}

function Install-RequiredAzmodules {

#Install NetGet
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "Installing NuGet PackageProvider..."
Write-Host ""
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | out-null
Write-Host "Curent version of NuGet PackageProvider is $versionOfNutGet which should be above the minimum version 2.8.5.201"

#>
<# Setting Installation Policy for PSRepository as Trusted:
Write-host " "
write-host "Setting Installation Policy for PSRepository as Trusted..."
Write-host " "
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Write-Host ""
#> # Setting Installation Policy for PSRepository as Trusted:

Write-Host "Checking if Az Module is installed..."
Write-host " "

#Check for required Az modules:
$ModuleToImport = "Az.Compute" #Curent version of Az.Compute 4.17.1,  -> This will install also curent version 2.6.0 of Az.Accounts module. # ADAL way not working anymore. Fortunately since Az.Accounts 2.2.0, there is Get-AzAccessToken which seems to make ADAL entirely unnecessary. Install New Az.Accounts with at least 2.2.0 version. Newest at this point 2.2.3
$ModuleToImport2 = "Az.Resources" #Curent version of Az.Resources 4.4.0
$ModuleToImport3 = "Az.KeyVault"
$ModuleToImport4 = "Az.Storage"


    # If module 1 is imported say that and do nothing
    Write-Host "Checking if the latest $ModuleToImport module is imported..."
    if (Get-Module | Where-Object {$_.Name -eq $ModuleToImport}) {
        write-host "Module $ModuleToImport is already imported." -ForegroundColor Green
    }
    else {

        # If module is not imported, but available on disk then import
          Write-Warning "$ModuleToImport module is not imported. Checking if it is available on disk to import..."
          Write-Host ""
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleToImport}) {
            Import-Module $ModuleToImport #-Verbose
             Write-Host "$ModuleToImport module was imported from disk" -ForegroundColor Green
        }
        else {
            Write-Warning "$ModuleToImport Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
            Write-Host ""
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $ModuleToImport | Where-Object {$_.Name -eq $ModuleToImport}) {
                Install-Module -Name $ModuleToImport -Force -Verbose -Scope CurrentUser
                Import-Module $ModuleToImport #-Verbose
                Write-Host "$ModuleToImport and Az.Accounts module was downloaded from internet, installed and imported" -ForegroundColor Green
            }
            else {
                
                 Write-Host ""
                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $ModuleToImport module not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }

    Write-host ""
        # If module 2 is imported say that and do nothing
    Write-Host "Checking if the latest $ModuleToImport2 module is imported..."
    if (Get-Module | Where-Object {$_.Name -eq $ModuleToImport2}) {
        write-host "Module $ModuleToImport2 is already imported." -ForegroundColor Green
    }
    else {

        # If module is not imported, but available on disk then import
          Write-Warning "$ModuleToImport2 module is not imported. Checking if it is available on disk to import..."
          Write-Host ""
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleToImport2}) {
            Import-Module $ModuleToImport2 #-Verbose
             Write-Host "$ModuleToImport2 module was imported from disk" -ForegroundColor Green
        }
        else {
            Write-Warning "$ModuleToImport2 Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
            Write-Host ""
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $ModuleToImport2 | Where-Object {$_.Name -eq $ModuleToImport2}) {
                Install-Module -Name $ModuleToImport2 -Force -Verbose -Scope CurrentUser
                Import-Module $ModuleToImport2 #-Verbose
                Write-Host "$ModuleToImport2 module was downloaded from internet, installed and imported" -ForegroundColor Green
            }
            else {
                
                 Write-Host ""
                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $ModuleToImport2 module not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
Write-host " "
        # If module 3 is imported say that and do nothing
    Write-Host "Checking if the latest $ModuleToImport3 module is imported..."
    if (Get-Module | Where-Object {$_.Name -eq $ModuleToImport3}) {
        write-host "Module $ModuleToImport3 is already imported." -ForegroundColor Green
    }
    else {

        # If module is not imported, but available on disk then import
          Write-Warning "$ModuleToImport3 module is not imported. Checking if it is available on disk to import..."
          Write-Host ""
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleToImport3}) {
            Import-Module $ModuleToImport3 #-Verbose
             Write-Host "$ModuleToImport3 module was imported from disk" -ForegroundColor Green
        }
        else {
            Write-Warning "$ModuleToImport3 Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
            Write-Host ""
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $ModuleToImport3 | Where-Object {$_.Name -eq $ModuleToImport3}) {
                Install-Module -Name $ModuleToImport3 -Force -Verbose -Scope CurrentUser
                Import-Module $ModuleToImport3 #-Verbose
                Write-Host "$ModuleToImport module was downloaded from internet, installed and imported" -ForegroundColor Green
            }
            else {
                
                 Write-Host ""
                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $ModuleToImport3 module not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
Write-host ""
        # If module 4 is imported say that and do nothing
    Write-Host "Checking if the latest $ModuleToImport4 module is imported..."
    if (Get-Module | Where-Object {$_.Name -eq $ModuleToImport4}) {
        write-host "Module $ModuleToImport4 is already imported." -ForegroundColor Green
    }
    else {

        # If module is not imported, but available on disk then import
          Write-Warning "$ModuleToImport4 module is not imported. Checking if it is available on disk to import..."
          Write-Host ""
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleToImport4}) {
            Import-Module $ModuleToImport4 #-Verbose
             Write-Host "$ModuleToImport4 module was imported from disk" -ForegroundColor Green
        }
        else {
            Write-Warning "$ModuleToImport4 Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
            Write-Host ""
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $ModuleToImport4 | Where-Object {$_.Name -eq $ModuleToImport4}) {
                Install-Module -Name $ModuleToImport4 -Force -Verbose -Scope CurrentUser
                Import-Module $ModuleToImport4 #-Verbose
                Write-Host "$ModuleToImport4 module was downloaded from internet, installed and imported" -ForegroundColor Green
            }
            else {
                
                 Write-Host ""
                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $ModuleToImport4 module not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
}

function Install-DotNet4.7.2 {

 # Check if the minimum version if installed (.NET Framework 4.7.2) ortherwise download and install .NET Framework 4.7.2
    
    $Net472Check = Get-ChildItem "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" | Get-ItemPropertyValue -Name Release
    if ($Net472Check -ge "461808") {
        Write-Host ".Net 4.7.2 (or higher) is already installed."
        Write-host " "
        
    }

#Download DotNEt:
if ($Net472Check -lt "461808") {

    #Set\Created path for DotNET to be downloaded:
    $pathdotnet = "C:\Unlock Disk\DotNet"

# if the path does not exist, create the folders:

    If(!(test-path $pathdotnet))
    {
      New-Item -ItemType Directory -Force -Path $pathdotnet
    }
    
    # DoTNet downoad URL:
    $DotNet472OfflineInstallerUrl = "https://go.microsoft.com/fwlink/?LinkID=863265"
    $OutFilePath = "$pathdotnet\NDP472-KB4054530-x86-x64-AllOS-ENU.exe"
    Write-host ""
    Write-host "You have installed on this system .Net Version $Net472Check, which is less than the minimum version 461808 (.DotNet 4.7.2) which is required for .Az module" -ForegroundColor Yellow
    Write-Host ""
    $agreeRestart = Read-Host "Would you like to proceed in downloading and installing .NET Framework 4.7.2? (Y\N)"
    
    if ($agreeRestart -eq "Y") {
    try {
    write-host ""
    write-host "Downloding .NET Framework 4.7.2 to path: $OutFilePath"
    write-host "Please wait..."
        $WebClient = [System.Net.WebClient]::new()
        $WebClient.Downloadfile($DotNet472OfflineInstallerUrl, $pathdotnet)
        $WebClient.Dispose()
    }
    catch {
        Invoke-WebRequest -Uri $DotNet472OfflineInstallerUrl -OutFile $OutFilePath
    }
    }
    elseif ($agreeRestart -eq "N")
    {
        Write-Host ""
        Write-Host "In order to use .Az powershell module which is necesary for running this script, .Net Framework must have a minimum version of 4.7.2. Please install manually at least .Net Framework version 4.7.2. at your earliest convenience and run again the script." -ForegroundColor "yellow"
        Write-Host ""
        Write-Host "Waiting for 30 seconds and stopping the script..."
        Start-Sleep -Seconds 30
       break
    }
    
    #Install DotNET:

    & "$pathdotnet\NDP472-KB4054530-x86-x64-AllOS-ENU.exe" /q /norestart

    while ($(Get-Process | Where-Object {$_.Name -like "*NDP472*"})) {
        Write-Host "Installing .Net Framework 4.7.2 ..."
        Start-Sleep -Seconds 5
    }

    Write-Host ".Net Framework 4.7.2 was installed successfully!" -ForegroundColor Green

    write-Host ""

    #Restart computer once the DotNET was installed:

    Write-Warning "You MUST restart computer $env:ComputerName in order to use .Net Framework 4.7.2! Please do so at your earliest convenience."
    $restartcomputer = Read-Host "Do you want to restart your computer now? (Y\N)"
    
       
    If ($restartcomputer -eq "y")
      { 
        Write-Host ""
        Write-Host "After the restart is complete, run again this script"
        Write-Host ""
        Write-Host "Waiting for 10 seconds and restarting this computer..."
        Start-Sleep -Seconds 10
        Restart-Computer -Force
      }
      
   
   elseif ($restartcomputer -eq "n")
    { 
        Write-Host ""
        Write-Host "After the restart is complete, run again this script"
        Write-Host ""
        Write-Host "You MUST restart $env:ComputerName in order to use .Net Framework 4.7.2! Please do so at your earliest convenience and run again the script." -ForegroundColor "yellow"
        Write-Host ""
        Write-Host "Waiting for 10 seconds and stopping the script..."
        Start-Sleep -Seconds 10
       break
      }

}
}

function Prerequisites {

#Install Az Module of necesary:
Write-host "Checking script prerequisites..."
Write-host " "

write-host "Checking DotNet version..."
Write-host " "

Install-DotNet4.7.2

#write-host "Checking if Required Az modules are installed..."
Write-host " "

Install-RequiredAzmodules

#Disable internet explorer enhanced security configuration:
Write-Host ""
Write-Host "Checking if Internet Explorer Enhanced Security is Disabled..."

  $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
  $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
  $CheckIfInternetExplorerEnhancedSecurityEnabledOrDisabled = (Get-ItemProperty -Path $AdminKey -Name "IsInstalled").IsInstalled #1= enabled - 0=disabled
  If ($CheckIfInternetExplorerEnhancedSecurityEnabledOrDisabled -eq "1")
 {
  Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
  Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
  Stop-Process -Name Explorer -Force
  Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
  }
  elseif ($CheckIfInternetExplorerEnhancedSecurityEnabledOrDisabled -eq "0") {Write-Host "IE Enhanced Security Configuration (ESC) is disabled." -ForegroundColor Green}


Write-host ""

}

function Get-SecretFromKV {

# Retreiving the .BEK file from the Keyvault
Write-host " "
Write-host "Retreiving the .BEK file from the Keyvault..." -ForegroundColor Green
Write-host " "
Write-host "Specify the disk or an existing VM that had a copy of this disk attached.."
Write-host ""

$SelectVmOrDiskArray = [ordered]@{ 'Existing Encrypted Disk' = 'Single Pass ONLY! -> Encrypted Disk you want to decrypt and it is attached to this VM (This method only works for Single Pass ) for retrieving  encryption settings' 
'Existing Encrypted VM' = 'Single and Dual Pass -> Existing Encrypted VM which has\had the disk you want to decrypt attached to it when this VM was encrypted for retrieving encryption settings'
 }

$SelectVmOrDisk = ($SelectVmOrDiskArray | Out-GridView -PassThru -Title "Specify the existing disk or the existing VM that had a copy of this disk attached").name


#Get current logged in user and active directory tenant details:
$ctx = Get-AzContext;
$adTenant = $ctx.Tenant.Id;
$currentUser = $ctx.Account.Id

#Selecting the DISK or existing VM:

If ($SelectVmOrDisk -eq "Existing Encrypted Disk")
{


$SelectDiskMangedOrUnmanagedArray = [ordered]@{ 'Managed' = 'Disk'
'Unmanaged' = 'Disk'}

$SelectDiskMangedOrUnmanaged = ($SelectDiskMangedOrUnmanagedArray | Out-GridView -PassThru -Title "Specify the disk type").name

# Disk is Managed
if ($SelectDiskMangedOrUnmanaged -eq "Managed")
{
#Get Secret Url and KEK Url - For Single Pass Managed disks:

#Select Managed Disk Name
$DiskName = ( Get-Azdisk  |Select-Object -Property Name,ManagedBy,ResourceGroupName,Location,DiskSizeGB,HyperVGeneration,DiskState,OSType| Out-GridView -Title "Select the disk name" -PassThru).Name

#Get Disk RG Name:
$DiskRGName = (Get-AzResource -Name $DiskName).ResourceGroupName

#Get Disk properties:
$Disk = Get-AzDisk -ResourceGroupName $DiskRGName -Name $DiskName;

#Creating Working path:
Write-Host " "
Write-Host "Checking if the work directoy exist and if not, creating work directory c:\Unlock Disk ... "
Write-Host " "
#Set\Created path for secret to be written:
$path = "C:\Unlock Disk\Secret_Disk_$DiskName"

# if the path does not exist, create the folders:

If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

#Get Secret Url, KeyVault Name, KEK Url and Secret Name - For Single Pass Managed disks: -> This does not work for dual pass since the encryption settings are not stored at disk level, only at VM level.

#first, clear all previous errors
$error.clear()

try {
$secretUrl = $Disk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SecretUrl
#Parse the secret URL:
$secretUri = [System.Uri] $secretUrl;
$keyVaultName = $secretUri.Host.Split('.')[0];
$KeKUrl = $Disk.EncryptionSettingsCollection.EncryptionSettings.KeyEncryptionKey.KeyURL
$secretName = $secretUri.Segments[2].TrimEnd('/')
}
catch {
}

#Check if the selected managed disk has encryption settings:

if (!$error) #enctyption settings were found
{
#List Encryption settings of the managed disk selected:
Write-host "Found below encryption settings for the selected managed disk:" -ForegroundColor Green
Write-host ""
Write-host "Key Vault name: $keyVaultName" -ForegroundColor Green
Write-host "Secret Name: $secretName" -ForegroundColor Green
Write-host "Secret URI: $secretUri" -ForegroundColor Green
Write-host "KEK URL: $KeKUrl" -ForegroundColor Green
if ($KeKUrl -eq $null)
{
Write-host ""
Write-host "Selected managed disk is encrypted with Single Pass using BEK" -ForegroundColor yellow
} 
elseif ($KeKUrl -ne $null)
{
Write-host ""
Write-host "Selected managed disk is encrypted with Single Pass using KEK" -ForegroundColor yellow
}
}


if ($error) #enctyption settings were NOT found
{
Write-host "No encryption settings were found for the selected managed disk, or the selected managed disk was encrypted with Dual Pass" -ForegroundColor Red
write-host ""
Write-host "Key Vault name: $keyVaultName" -ForegroundColor red
Write-host "Secret Name: $secretName" -ForegroundColor red
Write-host "Secret URI: $secretUri" -ForegroundColor red
Write-host "KEK URL: $KeKUrl" -ForegroundColor red
write-host ""
Write-host "If the managed disk was encrypted with Dual Pass, run again the script and select 'Existing VM' method" -ForegroundColor Yellow
write-host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}


}

# Disk is UnManaged
elseif ($SelectDiskMangedOrUnmanaged -eq "Unmanaged")
{
#Get Secret Url and KEK Url - For Single Pass UnManaged disks:

#Get Unmanaged Disk:

#Select Storage account:
$storageAccount = Get-AzStorageAccount | Out-GridView -Title "Select the storage account where the .vhd of the unmanaged disk resides..." -PassThru
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName)[0].Value
$context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey

#Select Container:
$container = (Get-AzStorageContainer -Context $context | Out-GridView -Title "Select the container where the .vhd of the unmanaged disk resides..." -PassThru).name

#Selecting the .VHD and Obtaining Disk Encryption Settings from page blob (VHD\Unmanaged disk) metadata:

$blob = Get-AzStorageBlob -Container $container -Context $context |Where-Object {$_.BlobType -eq 'PageBlob' -and $_.Name.EndsWith('.vhd')} | Select-Object -Property @{Label="Disk Name";Expression={$_.Name}},BlobType,@{Label="Disk Size";Expression={$_.ICloudBlob.Metadata.MicrosoftAzureCompute_DiskSizeInGB}},@{Label="OS or Data disk";Expression={$_.ICloudBlob.Metadata.MicrosoftAzureCompute_DiskType}},@{Label="Attached to VM";Expression={$_.ICloudBlob.Metadata.MicrosoftAzureCompute_VMName}},@{Label="EncryptionSettings";Expression={$_.ICloudBlob.Metadata.DiskEncryptionSettings}}| Out-GridView -Title "Select the .vhd of the unmanaged disk. Keep in mind that if the VHD is in a directory, that directory will not show in this list. If that is the case, you need to move\copy the VHD in the root of a container and run again the script (Ex: in 'vhds') ..." -PassThru 
$blobMetadata = $blob.EncryptionSettings

#Creating Working path:
$UnmanagedDiskName = $blob.'Disk Name'
Write-Host " "
Write-Host "Checking if the work directoy exist and if not, creating work directory c:\Unlock Disk ... "
Write-Host " "
#Set\Created path for secret to be written:
$path = "C:\Unlock Disk\Secret_Disk_$UnmanagedDiskName"
# if the path does not exist, create the folders:

If(!(test-path $path)) 
{
      New-Item -ItemType Directory -Force -Path $path 
}

#first, clear all previous errors
$error.clear()

try {
#Get Keyvault Name from page blob (VHD\Unmanaged disk) metadata:
$matchforKeyvaultName = select-string -Pattern 'vaults/(.*)' -inputobject $blobMetadata
$KeyVaultNametemp1= $matchforKeyvaultName.Matches.groups[1].value
$KeyVaultNametemp2 = $KeyVaultNametemp1.Split('"')
$KeyVaultName = $KeyVaultNametemp2.Split([Environment]::NewLine) | Select -First 1
}
catch{}
if (!$error) #enctyption settings were found
{
#Get Secret Name from page blob (VHD\Unmanaged disk) metadata:
$matchforsecretname = select-string -Pattern 'secretUrl":"(.*)' -inputobject $blobMetadata
$secretNametemp1= $matchforsecretname.Matches.groups[1].value
$secretNametemp2 = $secretNametemp1.Split('/')
$secretName = $secretNametemp2.Split([Environment]::NewLine) | Select -Skip 4 | Select -First 1

#Get SecretUrl from page blob (VHD\Unmanaged disk) metadata:
$matchforsecreturl = select-string -Pattern 'secretUrl":"(.*)' -inputobject $blobMetadata
$secretURLtemp1= $matchforsecreturl.Matches.groups[1].value
$secretURLtemp2 = $secretURLtemp1.Split('"')
$secretURL = $secretURLtemp2.Split([Environment]::NewLine) | Select -First 1

#Check if we can find a match for the KeyUrl in blob metadata, if yes, then blob is encrypted with KEK
$matchforkeyurl = select-string -Pattern 'KeyUrl":"(.*)' -inputobject $blobMetadata
if ($matchforkeyurl -ne $null)
{
#Get KEKUrl from page blob (VHD\Unmanaged disk) metadata:
$matchforkeyurl = select-string -Pattern 'KeyUrl":"(.*)' -inputobject $blobMetadata
$KeyURLtemp1 = $matchforkeyurl.Matches.groups[1].value
$KeyURLtemp2 = $KeyURLtemp1.Split('"')
$KeKURL = $KeyURLtemp2.Split([Environment]::NewLine) | Select -First 1
}
#List Encryption settings of the managed disk selected:
Write-host "Found below encryption settings for the selected unmanaged disk:" -ForegroundColor Green
Write-host ""
Write-host "Key Vault name: $keyVaultName" -ForegroundColor Green
Write-host "Secret Name: $secretName" -ForegroundColor Green
Write-host "Secret URL: $secretURL" -ForegroundColor Green
Write-host "KEK URL: $KeKUrl" -ForegroundColor Green
if ($KeKUrl -eq $null)
{
Write-host ""
Write-host "Selected unmanaged disk is encrypted with Single Pass using BEK" -ForegroundColor yellow
} 
elseif ($KeKUrl -ne $null)
{
Write-host ""
Write-host "Selected unmanaged disk is encrypted with Single Pass using KEK" -ForegroundColor yellow
}
}
if ($error) #enctyption settings were NOT found
{
Write-host "No encryption settings were found for the selected unmanaged disk, or the selected unmanaged disk was encrypted with Dual Pass" -ForegroundColor Red
write-host ""
Write-host "Key Vault name: $keyVaultName" -ForegroundColor red
Write-host "Secret Name: $secretName" -ForegroundColor red
Write-host "Secret URI: $secretUri" -ForegroundColor red
Write-host "KEK URL: $KeKUrl" -ForegroundColor red
write-host ""
Write-host "If the unmanaged disk was encrypted with Dual Pass, run again the script and select 'Existing VM' method" -ForegroundColor Yellow
write-host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}
}


#Ask user if he wants to set 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets or he confirms that he has those permission and this is not necesary
Write-Host ""
write-host "You will be asked to verify if your user has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName' or you want to try and give you permissions"  -ForegroundColor Yellow
Write-Host ""

# Check what is the permission model for the Key Vault (Access policy or RBAC)

$AccessPoliciesOrRBAC = (Get-AzKeyVault -VaultName $keyVaultName).EnableRbacAuthorization

if ($AccessPoliciesOrRBAC -eq $false)
{
Write-Host ""
Write-host "Permission model on the Key Vault '$keyVaultName' is 'Access policy'" -ForegroundColor Yellow
Write-Host ""
}
if ($AccessPoliciesOrRBAC -eq $true)
{
Write-Host ""
Write-host "Permission model on the Key Vault '$keyVaultName' is 'Azure role-based access control (RBAC)'" -ForegroundColor Yellow
Write-Host ""
}

#############
#Check if the curent user is present in any access policy

write-host "Script will also try and verify if the curent user '$currentUser' is present in any access policy and you will need to manually verify if the required permissions ares set" -ForegroundColor Yellow
Write-Host ""

$KeyVaultPoliciesDisplayName = (Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies.DisplayName
$KeyVaultPolicies = (Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies

if ($KeyVaultPoliciesDisplayName -notlike "*$currentUser*")
{
write-host ""
write-host "We could NOT verify that the curent user '$currentUser' user has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName'" -ForegroundColor red
write-host ""
write-host "Verify permissions by going to Azure Portal -> Key Vaults -> Select KeyVault 'kv-unlock-disk-we' -> Access policies -> Check if your user has permissions" -ForegroundColor yellow
write-host ""
}


if ($KeyVaultPoliciesDisplayName -like "*$currentUser*")
{
write-host ""
write-host "The curent user '$currentUser' was found in an Access policy on the Key Vault '$keyVaultName'" -ForegroundColor yellow
write-host ""

#user needs to verify if there is any Access policy that grants to the curent user at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault
write-host "Verify if your curent user '$currentUser' has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName'. Press 'OK' to continue" -ForegroundColor yellow
(Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies | Select 'DisplayName','PermissionstoKeys','PermissionstoSecrets','ObjectID'| Out-GridView -PassThru -Title "Verify if your curent user '$currentUser' has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName'. Press 'OK' to continue"
write-host ""
}

############

$AproveSetPermissions = read-host "Does your user have the permission above (Y) or you want to try and give you permissions (T)"

if ($AproveSetPermissions -eq "t")
{
#Set permissions for the current user to list,unwrap keys and retrieve secrets from KeyVault

$error.clear()
Write-Host ""
Write-Host "Setting KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for AAD user: $currentUser" -ForegroundColor Yellow
Write-Host ""
try {Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys list,unwrapkey -PermissionsToSecrets get,list -UserPrincipalName $currentUser -ErrorAction Stop}

catch {

  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""
}

###

if (!$error)
{
Write-Host ""
Write-Host "Permissions were set for user: $currentUser on Keyvault '$keyVaultName'. You could verify them also from  azure portal" -ForegroundColor green
Write-Host ""
}

####
 

if ($error)
{
Write-Host ""
Write-Warning "Permissions could NOT be set for user: $currentUser on Keyvault '$keyVaultName'."
Write-Host ""
Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow
Write-Host ""
# Get Object Id of your Azure AD user
Write-Host ""
Write-Host "Your user does not have access to the keys and secrets from Key Vault $keyVaultName and also cannot grant itself permissions" -ForegroundColor yellow
Write-Host ""
Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
Write-Host ""
Write-Host "If you do not have access, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
Write-Host ""
Write-Host "Another option would be the admin to go to Azure Portal -> Key Vaults -> Select KeyVault $keyVaultName and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
Write-Host ""
$EnterObjectIDOrStop = read-host "Do you want to try to set permission based on entered ObjectId (O) or stop the script (S)"

If ($EnterObjectIDOrStop -eq "S")
{
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
 }

If ($EnterObjectIDOrStop -eq "O")
{
  try
{
# Get Object Id of your Azure AD user
$ObjectIdAADUser = read-host "Type the object ID of your Azure AD user"
Write-Host ""
Write-Host "Setting KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for AAD user with ID: $ObjectIdAADUser" -ForegroundColor Yellow
Write-Host ""
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys list,unwrapkey -PermissionsToSecrets get,list -objectId $ObjectIdAADUser -ErrorAction Stop
Write-Host ""
Write-Host "Permissions were set for user: $ObjectIdAADUser on Keyvault '$keyVaultName'. Verify them also from  azure portal" -ForegroundColor green
Write-Host ""
}

catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""
}
}
elseif (!$error)
{
Write-Host ""
Write-Host "Permissions were set for user: $currentUser on Keyvault '$keyVaultName'. Verify them also from  azure portal" -ForegroundColor green
Write-Host ""
}
}

$error.clear()

try 
{$testingpermission = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction Stop}

catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""
}

if ($error)
{
Write-Host ""
Write-Warning "User: $currentUser does NOT have permissions on Keyvault '$keyVaultName'. Please check permissions or run again the script and try to set permissions"
Write-Host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}
}

#>
elseif ($AproveSetPermissions -eq "Y")
{
$error.clear()
try {(Get-AzKeyVaultSecret -VaultName $keyVaultName -ErrorAction Stop | where {$_.name -eq "$secretName"}).tags.MachineName}

catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""

}

if ($error)
{
Write-Host ""
Write-Warning "User: $currentUser does NOT have permissions on Keyvault '$keyVaultName'. Please check permissions and run again the script"
Write-Host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}
}

#

#############################
#Scenario where BEK was used:
#############################

if ($KeKUrl -eq $null) # if $kekurl is $null, then only BEK was used

{
#===========================================
# Write to console output the BEK file selected
Write-Host " "
Write-Host "You have selected $secretName secret"
Write-Host ""

#===========================================
#Formating the full path name of the .bek file that will be save to disk
$bekFilePath = $path +"\$secretName"

#=========================
# New method retreive the secret value of the secret-> https://stackoverflow.com/questions/63732583/warning-about-breaking-changes-in-the-cmdlet-get-azkeyvaultsecret-secretvaluet


$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName
$secretValueText = '';
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
try {
    $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}


#===========================================
# Downloding the BEK from the KV to disk (path)

$bekSecretBase64 = $secretValueText
#Convert base64 string to bytes and write to BEK file
$bekFileBytes = [System.Convert]::FromBase64String($bekSecretBase64);
$bekFileBytes = [Convert]::FromBase64String($bekSecretbase64) #other method
[System.IO.File]::WriteAllBytes($bekFilePath,$bekFileBytes)

Write-Host "The secret was saved under path:"  -ForegroundColor "Green"
Write-Host  "$bekFilePath"
Write-Host " "

#================================================
#start the unlocking process
Write-Host " "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"
Write-Host " "
#===========================================
#Select the drive letter of the attached disk you want to unlock
$DriveLetterOfDiskToUnlock = Read-Host "Select the drive letter of the disk that is attached to this current VM that you want to unlock (Ex: F:) "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"

#===========================================
#Unlocking the disk suing the BEK that was just downloaded from the KV
manage-bde -unlock $DriveLetterOfDiskToUnlock -RecoveryKey $BekFilePath
Write-Host " "
Write-Host "DONE!"  -ForegroundColor "Green"

#===========================================
#Open Unlocked drive
explorer.exe $DriveLetterOfDiskToUnlock
Write-Host ""
Write-Host "$DriveLetterOfDiskToUnlock drive was opened in Windows Explorer" -ForegroundColor "Green"
Write-Host ""
#================================================
}

###########################################
#Scenario where KEK was used (wrapped BEK):
###########################################

elseif ($KeKUrl -ne $null) # if $kekurl is NOT $null, then the BEK is wrapped (KEK)
{
$KekFilePath = $path +"\$secretName"
Write-Host "You have selected wrapped BEK (KEK) $secretName secret"
Write-Host " "
#Retrieve secret from KeyVault secretUrl
$keyVaultSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName #-Version $secretVersion;
$secretBase64 = $keyVaultSecret.SecretValue;
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretBase64)
$secretBase64 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

$Token = "Bearer {0}" -f (Get-AzAccessToken -Resource "https://vault.azure.net").Token
    
$headers = @{
    'Authorization' = $token
    "x-ms-version"  = '2014-08-01'
}

	# Place wrapped BEK in JSON object to send to KeyVault REST API

    ########################################################################################################################
    # 1. Retrieve the secret from KeyVault
    # 2. If Kek is not NULL, unwrap the secret with Kek by making KeyVault REST API call
    # 3. Convert Base64 string to bytes and write to the BEK file
    ########################################################################################################################

    #Call KeyVault REST API to Unwrap 

$jsonObject = @"
{
"alg": "RSA-OAEP",
"value" : "$secretBase64"
}
"@

    $unwrapKeyRequestUrl = $kekUrl+ "/unwrapkey?api-version=2015-06-01";
    $result = Invoke-RestMethod -Method POST -Uri $unwrapKeyRequestUrl -Headers $headers -Body $jsonObject -ContentType "application/json";

    #Convert Base64Url string returned by KeyVault unwrap to Base64 string
    $secretBase64 = $result.value;

    $secretBase64 = $secretBase64.Replace('-', '+');
$secretBase64 = $secretBase64.Replace('_', '/');
if($secretBase64.Length %4 -eq 2)
{
    $secretBase64+= '==';
}
elseif($secretBase64.Length %4 -eq 3)
{
    $secretBase64+= '=';
}

if($KekFilePath)
{
Write-Host " "
Write-Host "Writing wrapped BEK to disk.."
    $bekFileBytes = [System.Convert]::FromBase64String($secretBase64);
    [System.IO.File]::WriteAllBytes($KekFilePath,$bekFileBytes);
}

#===========================================
#Delete the key from the memory
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
clear-variable -name secretBase64

#================================================
#start the unlocking process
Write-Host " "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"
Write-Host " "
#Select the drive letter of the attached disk you want to unlock
$DriveLetterOfDiskToUnlock = Read-Host "Select the drive letter of the disk that is attached to this current VM that you want to unlock (Ex: F:) "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"

#===========================================
#Unlocking the disk using the BEK that was just downloaded from the KV
manage-bde -unlock $DriveLetterOfDiskToUnlock -RecoveryKey $KekFilePath
Write-Host " "
Write-Host "DONE!"  -ForegroundColor "Green"

#===========================================
#Open Unlocked drive
explorer.exe $DriveLetterOfDiskToUnlock
Write-Host ""
Write-Host "$DriveLetterOfDiskToUnlock drive was opened in Windows Explorer" -ForegroundColor "Green"
Write-Host ""
#================================================
}
#=========================================================
}
elseIf ($SelectVmOrDisk -eq "Existing Encrypted VM")

{


#Select VM Name
$vmName = ( Get-AzVM |Select-Object -Property Name,@{Label="VM Hostname (Maximum 15 characters)";Expression={$_.OsProfile.ComputerName}},ResourceGroupName,Location,@{Label="VM Size";Expression={$_.HardwareProfile.VmSize}},Tags,@{Name='OS Type'; Expression={$_.StorageProfile.OSDisk.OSType}},ProvisioningState,@{Name='OS disk Name'; Expression={$_.StorageProfile.OsDisk.Name}},@{Name='Nr. of Data disks'; Expression={($_.StorageProfile.dataDisks).count}},@{Name='Data disks Names'; Expression={$_.StorageProfile.DataDisks.Name}} | Out-GridView -Title "Select the VM (original VM, not Recovery VM) which had this disk attached when it was encrypted" -PassThru).Name


#Get RG Name from VM Properties
$rgName = (Get-AzResource -Name $vmName).ResourceGroupName


#Get VM properties:
$vm = Get-AzVm -ResourceGroupName $rgName -Name $vmName;

Write-Host " "
Write-Host "Checking if the work directoy exist and if not, creating work directory c:\Unlock Disk ... "
Write-Host " "

#Set\Created path for secret to be written:
$path = "C:\Unlock Disk\Secret_VM_$vmname"

# if the path does not exist, create the folders:

If(!(test-path $path)) 
{
      New-Item -ItemType Directory -Force -Path $path 
}
#===========================================
#Declaring Variables for obtaining the secret URL and KEK URL used in the encription process of the selected Original Encrypted VM disks:

#1. Disk is Managed:

if($null -eq $vm.StorageProfile.OsDisk.Vhd) #if this is null, then the disk is Managed
{
write-host "VM is using Managed disks"
write-host ""

#first, clear all previous errors
$error.clear()

try {

#Get Secret Url and KEK Url - For Single \ Dual Pass Managed disks:
$OSDiskName = $vm.StorageProfile.OsDisk.Name 
$OSDiskRGName = (Get-AzResource -Name $OSDiskName).ResourceGroupName
$OSDisk = Get-AzDisk -ResourceGroupName $OSDiskRGName -Name $OSDiskName 
$secretUrl = $OSDisk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SecretUrl
$KeKUrl = $OSDisk.EncryptionSettingsCollection.EncryptionSettings.KeyEncryptionKey.KeyURL

#===========================================
#Parse the secret URL:
$secretUriTemp = [System.Uri] $secretUrl;

#===========================================
#Retrieve keyvault name, secret name and secret version from secret URL:
$keyVaultNameTemp = $secretUriTemp.Host.Split('.')[0];
$secretNameTemp = $secretUriTemp.Segments[2].TrimEnd('/');
$secretVersionTemp = $secretUriTemp.Segments[3].TrimEnd('/');

#===========================================
}
catch {}

#Check if the selected VM with managed disk has encryption settings:

if (!$error) #enctyption settings were found
{
#List Encryption settings of VM with managed disk selected:
Write-host "Found below encryption settings from the selected VM for the encrypted managed disk:" -ForegroundColor Green
Write-host ""
Write-host "Key Vault name: $keyVaultNameTemp" -ForegroundColor Green
Write-host "Secret Name: $secretNameTemp" -ForegroundColor Green
Write-host "Secret URL: $secretUriTemp" -ForegroundColor Green
Write-host "Secret Version: $secretVersionTemp" -ForegroundColor Green
Write-host "KEK URL: $KeKUrl" -ForegroundColor Green

if ($KeKUrl -eq $null)
{
Write-host ""
Write-host "Selected managed disk of existing VM is encrypted with Single Pass using BEK" -ForegroundColor yellow
} 
elseif ($KeKUrl -ne $null)
{
Write-host ""
Write-host "Selected managed disk of existing VM is encrypted with Single Pass using KEK" -ForegroundColor yellow
}
}

if ($error) #enctyption settings were NOT found
{
Write-host "No encryption settings were found from the selected VM for the encrypted managed disk" -ForegroundColor Red
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

} 


#2. Disk is Unmanaged:

if($null -ne $vm.StorageProfile.OsDisk.Vhd) #if this is NOT null, then the disk is Unmanaged
{
write-host "VM is using Unmanaged disks"
write-host ""

#first, clear all previous errors
$error.clear()

try
{
#Get Secret Url and KEK Url - For Dual Pass Unmanaged disks:
$secretUrl = $VM.StorageProfile.OsDisk.encryptionSettings.DiskEncryptionKey.SecretUrl
$KeKUrl = $VM.StorageProfile.OsDisk.encryptionSettings.KeyEncryptionKey.KeyURL


#Get Secret Url and KEK Url - For Single Pass Unmanaged disks:
if ($secretUrl -eq $null)
{
$vm = Get-AzVm -ResourceGroupName $rgName -Name $vmName -Status #$vm variable needs to be declared again with the "-Status" parameter for obtaining the Secret Url and KEK Url on unmanaged disks
$secretUrl = $VM.Disks.encryptionSettings.DiskEncryptionKey.SecretUrl
$KeKUrl = $VM.Disks.encryptionSettings.KeyEncryptionKey.keyUrl
}
}

catch {}

if ($secretUrl -ne $null) #enctyption settings were found
{
#===========================================
#Parse the secret URL:
$secretUriTemp = [System.Uri] $secretUrl;

#===========================================
#Retrieve keyvault name, secret name and secret version from secret URL:
$keyVaultNameTemp = $secretUriTemp.Host.Split('.')[0];
$secretNameTemp = $secretUriTemp.Segments[2].TrimEnd('/');
$secretVersionTemp = $secretUriTemp.Segments[3].TrimEnd('/');

#===========================================

#List Encryption settings of VM with managed disk selected:
Write-host "Found below encryption settings from the selected VM for the encrypted managed disk:" -ForegroundColor Green
Write-host ""
Write-host "Key Vault name: $keyVaultNameTemp" -ForegroundColor Green
Write-host "Secret Name: $secretNameTemp" -ForegroundColor Green
Write-host "Secret URL: $secretUriTemp" -ForegroundColor Green
Write-host "Secret Version: $secretVersionTemp" -ForegroundColor Green
Write-host "KEK URL: $KeKUrl" -ForegroundColor Green
}

if ($secretUrl -eq $null) #enctyption settings were NOT found
{

Write-host "No encryption settings were found from the selected VM for the encrypted managed disk" -ForegroundColor Red
write-host ""
Write-host "Key Vault name: " -ForegroundColor Red
Write-host "Secret Name: " -ForegroundColor Red
Write-host "Secret URI: " -ForegroundColor Red
Write-host "Secret Version: " -ForegroundColor Red
Write-host "KEK URL: " -ForegroundColor Red
write-host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}

}

#===========================================
#Parse the secret URL:
$secretUri = [System.Uri] $secretUrl;

#===========================================
#Retrieve keyvault name, secret name and secret version from secret URL:
$keyVaultName = $secretUri.Host.Split('.')[0];
$secretName = $secretUri.Segments[2].TrimEnd('/');
$secretVersion = $secretUri.Segments[3].TrimEnd('/');

#===========================================


#Ask user if he wants to set 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets or he confirms that he has those permission and this is not necesary
Write-Host ""
write-host "You will be asked to verify if your user has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName' or you want to try and give you permissions" -ForegroundColor Yellow
Write-Host ""


# Check what is the permission model for the Key Vault (Access policy or RBAC)

$AccessPoliciesOrRBAC = (Get-AzKeyVault -VaultName $keyVaultName).EnableRbacAuthorization

if ($AccessPoliciesOrRBAC -eq $false)
{
Write-Host ""
Write-host "Permission model on the Key Vault '$keyVaultName' is 'Access policy'" -ForegroundColor Yellow
Write-Host ""
}
if ($AccessPoliciesOrRBAC -eq $true)
{
Write-Host ""
Write-host "Permission model on the Key Vault '$keyVaultName' is 'Azure role-based access control (RBAC)'" -ForegroundColor Yellow
Write-Host ""
}

#############
#Check if the curent user is present in any access policy

write-host "Script will also try and verify if the curent user '$currentUser' is present in any access policy and you will need to manually verify if the required permissions ares set" -ForegroundColor Yellow
Write-Host ""

$KeyVaultPoliciesDisplayName = (Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies.DisplayName
$KeyVaultPolicies = (Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies

if ($KeyVaultPoliciesDisplayName -notlike "*$currentUser*")
{
write-host ""
write-host "We could NOT verify that the curent user '$currentUser' user has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName'" -ForegroundColor red
write-host ""
write-host "Verify permissions by going to Azure Portal -> Key Vaults -> Select KeyVault 'kv-unlock-disk-we' -> Access policies -> Check if your user has permissions" -ForegroundColor yellow
write-host ""
}


if ($KeyVaultPoliciesDisplayName -like "*$currentUser*")
{
write-host ""
write-host "The curent user '$currentUser' was found in an Access policy on the Key Vault '$keyVaultName'" -ForegroundColor yellow
write-host ""
#user needs to verify if there is any Access policy that grants to the curent user at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault
write-host "Verify if your curent user '$currentUser' has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName'. Press 'OK' to continue" -ForegroundColor yellow
(Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies | Select 'DisplayName','PermissionstoKeys','PermissionstoSecrets','ObjectID'| Out-GridView -PassThru -Title "Verify if your curent user '$currentUser' has at least 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets from Key Vault '$keyVaultName'. Press 'OK' to continue"
write-host ""
}

############

$AproveSetPermissions = read-host "Does your user have the permission above (Y) or you want to try and give you permissions (T)"

if ($AproveSetPermissions -eq "t")
{

#Set permissions for the current user to list,unwrap keys and retrieve secrets from KeyVault

$error.clear()
Write-Host ""
Write-Host "Setting KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for AAD user: $currentUser" -ForegroundColor Yellow
Write-Host ""
try {Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys list,unwrapkey -PermissionsToSecrets get,list -UserPrincipalName $currentUser -ErrorAction Stop}


catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""

}

###

if (!$error)
{
Write-Host ""
Write-Host "Permissions were set for user: $currentUser on Keyvault '$keyVaultName'. You could verify them also from  azure portal" -ForegroundColor green
Write-Host ""
}

####

if ($error)
{
Write-Host ""
Write-Warning "Permissions could NOT be set for user: $currentUser on Keyvault '$keyVaultName'."
Write-Host ""
Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow
Write-Host ""
# Get Object Id of your Azure AD user
Write-Host ""
Write-Host "Your user does not have access to the keys and secrets from Key Vault $keyVaultName and also cannot grant itself permissions" -ForegroundColor yellow
Write-Host ""
Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
Write-Host ""
Write-Host "If you do not have access, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
Write-Host ""
Write-Host "Another option would be the admin to go to Azure Portal -> Key Vaults -> Select KeyVault $keyVaultName and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
Write-Host ""
$EnterObjectIDOrStop = read-host "Do you want to try to set permission based on entered ObjectId (O) or stop the script (S)"

If ($EnterObjectIDOrStop -eq "S")
{
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
 }

If ($EnterObjectIDOrStop -eq "O")
{
  try
{

# Get Object Id of your Azure AD user
$ObjectIdAADUser = read-host "Type the object ID of your Azure AD user"
Write-Host ""
Write-Host "Setting KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for AAD user with ID: $ObjectIdAADUser" -ForegroundColor Yellow
Write-Host ""
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys list,unwrapkey -PermissionsToSecrets get,list -objectId $ObjectIdAADUser -ErrorAction Stop
Write-Host ""
Write-Host "Permissions were set for user: $ObjectIdAADUser on Keyvault '$keyVaultName'. Verify them also from  azure portal" -ForegroundColor green
Write-Host ""
}

catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""

}
}

elseif (!$error)
{
Write-Host ""
Write-Host "Permissions were set for user: $currentUser on Keyvault '$keyVaultName'. Verify them also from  azure portal" -ForegroundColor green
Write-Host ""
}
}


$error.clear()
try 
{$testingpermission = Get-AzKeyVaultSecret -VaultName $keyVaultName -ErrorAction Stop}
catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""

}
if ($error)
{
Write-Host ""
Write-Warning "User: $currentUser does NOT have permissions on Keyvault '$keyVaultName'. Please check permissions or run again the script and try to set permissions"
Write-Host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}
}
#>
elseif ($AproveSetPermissions -eq "Y")
{
$error.clear()
try {(Get-AzKeyVaultSecret -VaultName $keyVaultName -ErrorAction Stop | where {$_.name -eq "$secretName"}).tags.MachineName }

catch {
  Write-Host ""
  Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
  Write-Host -Foreground Red -Background Black ($Error[0])
  Write-Host ""
}

if ($error)
{
Write-Host ""
Write-Warning "User: $currentUser does NOT have permissions on Keyvault '$keyVaultName'. Please check permissions and run again the script"
Write-Host ""
Write-Host "Script will exit in 30 seconds"
Start-Sleep -Seconds 30
Exit
}
}

#
#===========================================
# List the secrets for all the disks of Original Encrypted VM:
$hostname = (Get-AzKeyVaultSecret -VaultName $keyVaultName | where {$_.name -eq "$secretName"}).tags.MachineName  
Write-host "Available Secrets for VM $vmName :" -ForegroundColor Green
Get-AzKeyVaultSecret -VaultName $keyVaultName | where {($_.Tags.MachineName -like ("$hostname"))} | Sort-Object -Property Created | ft  Created, `
            @{Label="Content Type";Expression={$_.ContentType}}, `
            @{Label ="Volume"; Expression = {$_.Tags.VolumeLetter}}, `
            @{Label ="DiskEncryptionKeyFileName"; Expression = {$_.Tags.DiskEncryptionKeyFileName}}




#===========================================
#===========================================

# Is it the OS disk or a Data disk
$IsItTheOSdiskOraDataDiskArray = [ordered]@{ 'OS disk' = 'The encrypted disk is an OS disk'
 'Data Disk' = 'The encrypted disk is a Data disk'}

$IsItTheOSdiskOraDataDisk = ($IsItTheOSdiskOraDataDiskArray | Out-GridView -PassThru -Title "Select the type of the encrypted disk").name

    # Is it the OS disk
    If ($IsItTheOSdiskOraDataDisk -eq "OS disk")
        {

        #Select manually the secret name or retrieve it automatically

        $SelectSecretManuallyOrRetrieveItAutomaticallyArray = [ordered]@{ 'Select Secret Manually from a list' = 'Select the secret manually from a list of all secrets from the KeyVault'
         'Auto select select secret' = 'The secret will be automatically selected from the KeyVault'}

        $SelectSecretManuallyOrRetrieveItAutomatically = ($SelectSecretManuallyOrRetrieveItAutomaticallyArray | Out-GridView -PassThru -Title "Select the Secret Manually Or Retrieve It Automatically from teh KeyVault").name

        #Select Secret Manually from a list
        If ($SelectSecretManuallyOrRetrieveItAutomatically -eq "Select Secret Manually from a list")
            {
            # Select secret:
            Write-host ""
            Write-host "Select the secret that was used to encrypt the disk by checking the drive letter and creation timestamp.."
            Write-host ""

            $secretName = (Get-AzKeyVaultSecret -VaultName $keyVaultName | where {($_.Tags.MachineName -like ("$hostname"))} | Select-Object -Property @{Label="VM Hostname (Maximum 15 characters)";Expression={$_.Tags.MachineName}},@{Label="Content Type";Expression={$_.ContentType}}, @{Label ="Volume letter the disk had on the Original VM"; Expression = {$_.Tags.VolumeLetter}},@{Label ="Volume Label"; Expression = {$_.Tags.VolumeLabel}} ,Name,@{Label ="Key Vault Name"; Expression = {$_.VaultName}}, enabled, expires, created, updated,version,@{Label ='Disk Encryption Key Encryption Key (KEK) URL'; Expression = {$_.Tags.DiskEncryptionKeyEncryptionKeyURL}} |Sort-Object -Property updated -Descending | Out-GridView -Title "Select the secret that was used to encrypt the disk by checking the drive letter and creation timestamp" -PassThru).Name

            }
            

    #Retrieve It Automatically
    elseIf ($SelectSecretManuallyOrRetrieveItAutomatically -eq "Auto select select secret")
        {
        $SecretUsed = Get-AzKeyVaultSecret -VaultName $keyVaultName | where {($_.Tags.DiskEncryptionKeyFileName -match $secretName)} | Sort-Object -Property Created | ft  Created, `
            @{Label="Content Type";Expression={$_.ContentType}}, `
            @{Label ="Volume"; Expression = {$_.Tags.VolumeLetter}}, `
            @{Label ="DiskEncryptionKeyFileName"; Expression = {$_.Tags.DiskEncryptionKeyFileName}}

        Write-Host "Secret used is:"
        $SecretUsed
        }
        }

    # Is it a Data disk

    #Select Secret Manually from a list

    elseIf ($IsItTheOSdiskOraDataDisk -eq "Data Disk")
        {
        # Select secret:
        Write-host ""
        Write-host "Select the secret that was used to encrypt the disk by checking the drive letter and creation timestamp.."
        Write-host ""

        $secretName = (Get-AzKeyVaultSecret -VaultName $keyVaultName | where {($_.Tags.MachineName -like ("$hostname"))} | Select-Object -Property @{Label="VM Hostname (Maximum 15 characters)";Expression={$_.Tags.MachineName}},@{Label="Content Type";Expression={$_.ContentType}}, @{Label ="Volume letter the disk had on the Original VM"; Expression = {$_.Tags.VolumeLetter}},@{Label ="Volume Label"; Expression = {$_.Tags.VolumeLabel}} ,Name,@{Label ="Key Vault Name"; Expression = {$_.VaultName}}, enabled, expires, created, updated,version,@{Label ='Disk Encryption Key Encryption Key (KEK) URL'; Expression = {$_.Tags.DiskEncryptionKeyEncryptionKeyURL}} |Sort-Object -Property updated -Descending | Out-GridView -Title "Select the secret that was used to encrypt the disk by checking the drive letter and creation timestamp" -PassThru).Name

        }


#===========================================

#############################
#Scenario where BEK was used:
#############################

if ($KeKUrl -eq $null) # if $kekurl is $null, then only BEK was used

{
#===========================================
# Write to console output the BEK file selected
Write-Host " "
Write-Host "You have selected $secretName secret"
Write-Host ""

#===========================================
#Formating the full path name of the .bek file that will be save to disk
$bekFilePath = $path +"\$secretName"

#=========================
# New method retreive the secret value of the secret-> https://stackoverflow.com/questions/63732583/warning-about-breaking-changes-in-the-cmdlet-get-azkeyvaultsecret-secretvaluet

$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName
$secretValueText = '';
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
try {
    $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}


#===========================================
# Downloding the BEK from the KV to disk (path)

$bekSecretBase64 = $secretValueText
#Convert base64 string to bytes and write to BEK file
$bekFileBytes = [System.Convert]::FromBase64String($bekSecretBase64);
$bekFileBytes = [Convert]::FromBase64String($bekSecretbase64) #other method
[System.IO.File]::WriteAllBytes($bekFilePath,$bekFileBytes)

Write-Host "The secret was saved under path:"  -ForegroundColor "Green"
Write-Host  "$bekFilePath"
Write-Host " "

#================================================
#start the unlocking process
Write-Host " "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"
Write-Host " "
#===========================================
#Select the drive letter of the attached disk you want to unlock
$DriveLetterOfDiskToUnlock = Read-Host "Select the drive letter of the disk that is attached to this current VM that you want to unlock (Ex: F:) "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"

#===========================================
#Unlocking the disk suing the BEK that was just downloaded from the KV
manage-bde -unlock $DriveLetterOfDiskToUnlock -RecoveryKey $BekFilePath
Write-Host " "
Write-Host "DONE!"  -ForegroundColor "Green"

#===========================================
#Open Unlocked drive
explorer.exe $DriveLetterOfDiskToUnlock
Write-Host ""
Write-Host "$DriveLetterOfDiskToUnlock drive was opened in Windows Explorer" -ForegroundColor "Green"
Write-Host ""
#================================================
}

###########################################
#Scenario where KEK was used (wrapped BEK):
###########################################

elseif ($KeKUrl -ne $null) # if $kekurl is NOT $null, then the BEK is wrapped (KEK)
{
$KekFilePath = $path +"\$secretName"
Write-Host "You have selected wrapped BEK (KEK) $secretName secret"
Write-Host " "
#Retrieve secret from KeyVault secretUrl
$keyVaultSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName #-Version $secretVersion;
$secretBase64 = $keyVaultSecret.SecretValue;
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretBase64)
$secretBase64 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

$Token = "Bearer {0}" -f (Get-AzAccessToken -Resource "https://vault.azure.net").Token
    
$headers = @{
    'Authorization' = $token
    "x-ms-version"  = '2014-08-01'
}

	# Place wrapped BEK in JSON object to send to KeyVault REST API

    ########################################################################################################################
    # 1. Retrieve the secret from KeyVault
    # 2. If Kek is not NULL, unwrap the secret with Kek by making KeyVault REST API call
    # 3. Convert Base64 string to bytes and write to the BEK file
    ########################################################################################################################

    #Call KeyVault REST API to Unwrap 

$jsonObject = @"
{
"alg": "RSA-OAEP",
"value" : "$secretBase64"
}
"@

    $unwrapKeyRequestUrl = $kekUrl+ "/unwrapkey?api-version=2015-06-01";
    $result = Invoke-RestMethod -Method POST -Uri $unwrapKeyRequestUrl -Headers $headers -Body $jsonObject -ContentType "application/json";

    #Convert Base64Url string returned by KeyVault unwrap to Base64 string
    $secretBase64 = $result.value;

    $secretBase64 = $secretBase64.Replace('-', '+');
$secretBase64 = $secretBase64.Replace('_', '/');
if($secretBase64.Length %4 -eq 2)
{
    $secretBase64+= '==';
}
elseif($secretBase64.Length %4 -eq 3)
{
    $secretBase64+= '=';
}

if($KekFilePath)
{
Write-Host " "
Write-Host "Writing wrapped BEK to disk.."
    $bekFileBytes = [System.Convert]::FromBase64String($secretBase64);
    [System.IO.File]::WriteAllBytes($KekFilePath,$bekFileBytes);
}

#===========================================
#Delete the key from the memory
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
clear-variable -name secretBase64

#================================================
#start the unlocking process
Write-Host " "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"
Write-Host " "
#Select the drive letter of the attached disk you want to unlock
$DriveLetterOfDiskToUnlock = Read-Host "Select the drive letter of the disk that is attached to this current VM that you want to unlock (Ex: F:) "
Write-Host "Starting the unlock process... "  -ForegroundColor "Green"

#===========================================
#Unlocking the disk using the BEK that was just downloaded from the KV
manage-bde -unlock $DriveLetterOfDiskToUnlock -RecoveryKey $KekFilePath
Write-Host " "
Write-Host "DONE!"  -ForegroundColor "Green"

#===========================================
#Open Unlocked drive
explorer.exe $DriveLetterOfDiskToUnlock
Write-Host ""
Write-Host "$DriveLetterOfDiskToUnlock drive was opened in Windows Explorer" -ForegroundColor "Green"
Write-Host ""
#================================================

}
}
}

#============================================End of Functions definition================================================

#Starting the script:

Prerequisites

Authentication

Get-SecretFromKV
