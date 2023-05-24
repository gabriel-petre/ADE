<# 
=======================================================================
Download Script:
•	From a windows VM (local):
    https://github.com/gabriel-petre/ADE/blob/main/GetSecret/GetSecret_1.0.ps1

•	From Azure Cloud Shell with command:
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gabriel-petre/ADE/main/GetSecret/GetSecret_1.0.ps1" -OutFile $home/GetSecret_1.0.ps1


How to run the PowerShell script:
•	When used on a windows VM (local):
    o	./GetSecret_1.0.ps1 -Mode "local" -subscriptionId "sub ID" -DiskName "Encryppted disk name"
    o	./GetSecret_1.0.ps1 -Mode "local" -subscriptionId " sub ID " -DiskName " Encryppted disk name " -SecretVersion "Secret version"
    o	./GetSecret_1.0.ps1 -Mode "local" -subscriptionId " sub ID " -DiskName " Encryppted disk name " -SecretVersion "Secret version" -KekVersion "Key Version"

•	When used from Cloud Shell:
    o	./GetSecret_1.0.ps1 -Mode "cloudshell" -subscriptionId "sub ID" -DiskName "Encryppted disk name"
    o   ./GetSecret_1.0.ps1 -Mode " cloudshell " -subscriptionId " sub ID " -DiskName " Encryppted disk name " -SecretVersion "Secret version"
    o   ./GetSecret_1.0.ps1 -Mode " cloudshell " -subscriptionId " sub ID " -DiskName " Encryppted disk name " -SecretVersion "Secret version" -KekVersion "Key Version"
    o	./GetSecret_1.0.ps1 -Mode "cloudshell" -subscriptionId "sub ID" -DiskName "Encryppted disk name" -UseDeviceAuthentication

What it does:
    1.	Checks if prerequisites are installed. If they aren't, it will install them. (Only for "local" scenario)
        Prerequisites required:
        •	Az.Compute Powershell module
        •	Az.Resources Powershell module
        •	Az.KeyVault Powershell module
        •	Az.Storage Powershell module
        •	.Net 4.7.2 (or higher)
        •	"NuGet" PackageProvider (MinimumVersion 2.8.5.201)
    2.	Display the encryption settings for future use.
    3.	check if the current user has the proper permissions and if not, it will assign those permissions (supports both of available permissions model: Access policy or RBAC)
    4.	Finds the proper secret that was used originally to encrypt the disk.
    5.	Downloads that secret which was used to originally encrypt the disk to the working directory.
    6.	Unlocks the disk (only for "local" scenario)

Troubleshooting Scenarios when the script can be used (not limited to the ones bellow):
    •	When can script be used locally:
    When cx cannot create a new VM due to cost, permissions, does not have access to cloud shell or complexity of the operation, but already has an existing VM with internet access that he can use.
    •	When can script be used in cloud shell:
    When cx cannot create a new VM due to cost, permissions, does not have access to cloud shell, complexity of the operation or does not have an existing VM or exiting VM with internet access that he can use.

Advantages:
•	This PowerShell script was designed to be used from locally or from Azure cloud shell, to eliminate the need of PowerShell prerequisites needed in the manual process and which caused delays or additional issues due to the diversity of environments in terms of PowerShell version, OS version, user permissions, internet connectivity etc.
•	The duration for this process using this script is an average of 3 minutes, which is far more less than the manual process which can take hours depending on the complexity of scenarios, environment variables, customer limitations, level of expertise.
•	Reduced risk of human errors in gathering and using encryption settings
•	No internet access is required on the Rescue VM which is useful for users with restricted environments if it is used from azure Cloud Shell
•	Insignificant number of initial input data needed to run this script.
•	Additional checks during this process to reduce or prevent the risk of a script failure due to the variety of environments.
•	Additional explanatory details are offered during the process, which helps the user to learn theoretical aspects along the way.
•	Error handling for the most common errors in terms of auto-resolving or guidance for the manual process of resolving the issue.
•	Offers the possibility of using the script multiple times if the troubleshooting scenario requires this.

Supported scenarios: 
•	Retrieve secrets (BEK or KEK) for encrypted with Single Pass managed disks (OS or data), with Windows or Linux as the operating system (gen 1 or gen 2)

Unsupported scenarios:
•	For Windows:
    o	Retrieve secrets (BEK or KEK) for encrypted with Single Pass unmanaged disks (OS or data), with Windows as the operating system (gen 1 or gen 2)
    o	Retrieve secrets (BEK or KEK) for encrypted with Dual Pass managed disks (OS or data), with Windows as the operating system (gen 1 or gen 2)
    o	Retrieve secrets (BEK or KEK) for encrypted with Dual Pass unmanaged disks (OS or data) with Windows as the operating system (gen 1 or gen 2)
•	For Linux:
    o	Retrieve secrets (BEK or KEK) for encrypted with Single Pass unmanaged disks (OS or data), with Linux as the operating system (gen 1 or gen 2)
    o	Retrieve secrets (BEK or KEK) for encrypted with Dual Pass managed disks (OS or data), with Linux as the operating system (gen 1 or gen 2)
    o	Retrieve secrets (BEK or KEK) for encrypted with Dual Pass unmanaged disks (OS or data), with Linux as the operating system (gen 1 or gen 2)

    Requirements:
    •	If run locally, VM from which you are running the script, needs to have internet access.
    •	If run from Azure Cloud Shell, user needs access to Azure Cloud Shell
    •	The user needs to have access to assign the proper permissions if they do not already have them
        o	Permission that will be assigned by the script based on the two scenarios:
            	If permission model on the Key Vault is 'Access policy’ based:
                    It will set for current user “list” and “unwrapkey” permissions on the keys from the Key Vault.
                    It will set for current user ‘list” and “get” permissions on secrets from the Key Vault.
            	If permission model on the Key Vault is ‘RBAC’ based:
                    It will assign to current user the "Key Vault Administrator" role.

Changes:
On 2nd of March 
    • removed the default use device code authentication instead of a browser control.
    • added optional switch -UseDeviceAuthentication switch to be used only when you need the device code authentication instead of a browser control.

On 7th of April
    Added the optional parameter -SecretVersion
    Added the optional parameter -KekVersion

    You can manually specify what key or secret version to use. This is useful if the disk is using an old key or secret version which expired or is disabled and it is still in encryption settings of the disk...

=======================================================================
#>

#============================================Start of Functions definition================================================

Param (

    [Parameter(Mandatory = $true)] [String] $Mode,
    [Parameter(Mandatory = $true)] [String] $subscriptionId,
    [Parameter(Mandatory = $true)] [String] $DiskName,
    [Parameter(Mandatory = $false)] [String] $SecretVersion,
    [Parameter(Mandatory = $false)] [String] $KekVersion,
    [Parameter(Mandatory = $false)] [switch] $UseDeviceAuthentication

)

if ($Mode -eq "local") {
    Write-Host ""
    Write-Host "Disabling warning messages to users that the cmdlets used in this script may be changed in the future." -ForegroundColor green
    Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
    Write-Host ""

    function Authentication {

        #Login Part:

        Write-host ""
        Write-host "Login to your Az Account.."
        Write-host ""
        Login-AzAccount #-WarningAction:SilentlyContinue
        #Connect-AzAccount -TenantId 72f988bf-86f1-41af-91ab-2d7cd011db47

        Set-AzContext -Subscription $subscriptionId | out-null
        Write-Host""
        Write-Host "Subscription with ID '$subscriptionId' was selected"
        Write-Host""

    }

    function Install-RequiredAzmodules {

        #Install NuGet
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $error.clear() 
        try { $NuGet = Get-PackageProvider nuget -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
        catch {
            Write-Host ""
        }

        # if there is not error on the set permission operation, permissions were set successfully
        if (!$error) {
       
                    
            Write-Host "NuGet version $NuGetversion is already installed"
            Write-Host ""
        }

                
        if ($error) {

            Write-Host "Installing latest version of NuGet PackageProvider..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm | out-null
            Write-Host ""
        }

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
        $ModuleToImport = "Az.Compute" #Current version of Az.Compute 4.17.1,  -> This will install also Current version 2.6.0 of Az.Accounts module. # ADAL way not working anymore. Fortunately since Az.Accounts 2.2.0, there is Get-AzAccessToken which seems to make ADAL entirely unnecessary. Install New Az.Accounts with at least 2.2.0 version. Newest at this point 2.2.3
        $ModuleToImport2 = "Az.Resources" #Current version of Az.Resources 4.4.0
        $ModuleToImport3 = "Az.KeyVault"
        $ModuleToImport4 = "Az.Storage"


        # If module 1 is imported say that and do nothing
        Write-Host "Checking if the latest $ModuleToImport module is imported..."
        if (Get-Module | Where-Object { $_.Name -eq $ModuleToImport }) {
            write-host "Module $ModuleToImport is already imported." -ForegroundColor Green
        }
        else {

            # If module is not imported, but available on disk then import
            Write-Warning "$ModuleToImport module is not imported. Checking if it is available on disk to import..."
            Write-Host ""
            if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleToImport }) {
                Import-Module $ModuleToImport #-Verbose
                Write-Host "$ModuleToImport module was imported from disk" -ForegroundColor Green
            }
            else {
                Write-Warning "$ModuleToImport Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
                Write-Host ""
                # If module is not imported, not available on disk, but is in online gallery then install and import
                if (Find-Module -Name $ModuleToImport | Where-Object { $_.Name -eq $ModuleToImport }) {
                    Install-Module -Name $ModuleToImport -Force -Verbose
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
        if (Get-Module | Where-Object { $_.Name -eq $ModuleToImport2 }) {
            write-host "Module $ModuleToImport2 is already imported." -ForegroundColor Green
        }
        else {

            # If module is not imported, but available on disk then import
            Write-Warning "$ModuleToImport2 module is not imported. Checking if it is available on disk to import..."
            Write-Host ""
            if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleToImport2 }) {
                Import-Module $ModuleToImport2 #-Verbose
                Write-Host "$ModuleToImport2 module was imported from disk" -ForegroundColor Green
            }
            else {
                Write-Warning "$ModuleToImport2 Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
                Write-Host ""
                # If module is not imported, not available on disk, but is in online gallery then install and import
                if (Find-Module -Name $ModuleToImport2 | Where-Object { $_.Name -eq $ModuleToImport2 }) {
                    Install-Module -Name $ModuleToImport2 -Force -Verbose
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
        if (Get-Module | Where-Object { $_.Name -eq $ModuleToImport3 }) {
            write-host "Module $ModuleToImport3 is already imported." -ForegroundColor Green
        }
        else {

            # If module is not imported, but available on disk then import
            Write-Warning "$ModuleToImport3 module is not imported. Checking if it is available on disk to import..."
            Write-Host ""
            if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleToImport3 }) {
                Import-Module $ModuleToImport3 #-Verbose
                Write-Host "$ModuleToImport3 module was imported from disk" -ForegroundColor Green
            }
            else {
                Write-Warning "$ModuleToImport3 Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
                Write-Host ""
                # If module is not imported, not available on disk, but is in online gallery then install and import
                if (Find-Module -Name $ModuleToImport3 | Where-Object { $_.Name -eq $ModuleToImport3 }) {
                    Install-Module -Name $ModuleToImport3 -Force -Verbose
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
        if (Get-Module | Where-Object { $_.Name -eq $ModuleToImport4 }) {
            write-host "Module $ModuleToImport4 is already imported." -ForegroundColor Green
        }
        else {

            # If module is not imported, but available on disk then import
            Write-Warning "$ModuleToImport4 module is not imported. Checking if it is available on disk to import..."
            Write-Host ""
            if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleToImport4 }) {
                Import-Module $ModuleToImport4 #-Verbose
                Write-Host "$ModuleToImport4 module was imported from disk" -ForegroundColor Green
            }
            else {
                Write-Warning "$ModuleToImport4 Module is not already imported and not available on the disk. Checking if it is available online to download then install and import..."
                Write-Host ""
                # If module is not imported, not available on disk, but is in online gallery then install and import
                if (Find-Module -Name $ModuleToImport4 | Where-Object { $_.Name -eq $ModuleToImport4 }) {
                    Install-Module -Name $ModuleToImport4 -Force -Verbose
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

        # Check if the minimum version if installed (.NET Framework 4.7.2) otherwise download and install .NET Framework 4.7.2
    
        $Net472Check = Get-ChildItem "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" | Get-ItemPropertyValue -Name Release
        if ($Net472Check -ge "461808") {
            Write-Host ".Net 4.7.2 (or higher) is already installed." -foreground green
       
        
        }

        #Download DotNEt:
        if ($Net472Check -lt "461808") {

            #Set\Created path for DotNET to be downloaded:
            $pathdotnet = "C:\Unlock Disk\DotNet"

            # if the path does not exist, create the folders:

            If (!(test-path $pathdotnet)) {
                New-Item -ItemType Directory -Force -Path $pathdotnet
            }
    
            # DoTNet download URL:
            $DotNet472OfflineInstallerUrl = "https://go.microsoft.com/fwlink/?LinkID=863265"
            $OutFilePath = "$pathdotnet\NDP472-KB4054530-x86-x64-AllOS-ENU.exe"
            Write-host ""
            Write-host "You have installed on this system .Net Version $Net472Check, which is less than the minimum version 461808 (.DotNet 4.7.2) which is required for .Az module" -ForegroundColor Yellow
            Write-Host ""
            $agreeRestart = Read-Host "Would you like to proceed in downloading and installing .NET Framework 4.7.2? (Y\N)"
    
            if ($agreeRestart -eq "Y") {
                try {
                    write-host ""
                    write-host "Downloading .NET Framework 4.7.2 to path: $OutFilePath"
                    write-host "Please wait..."
                    $WebClient = [System.Net.WebClient]::new()
                    $WebClient.Downloadfile($DotNet472OfflineInstallerUrl, $pathdotnet)
                    $WebClient.Dispose()
                }
                catch {
                    Invoke-WebRequest -Uri $DotNet472OfflineInstallerUrl -OutFile $OutFilePath
                }
            }
            elseif ($agreeRestart -eq "N") {
                Write-Host ""
                Write-Host "In order to use .Az powershell module which is necessary for running this script, .Net Framework must have a minimum version of 4.7.2. Please install manually at least .Net Framework version 4.7.2. at your earliest convenience and run again the script." -ForegroundColor "yellow"
                Write-Host ""
                Write-Host "Waiting for 30 seconds and stopping the script..."
                Start-Sleep -Seconds 30
                break
            }
    
            #Install DotNET:

            & "$pathdotnet\NDP472-KB4054530-x86-x64-AllOS-ENU.exe" /q /norestart

            while ($(Get-Process | Where-Object { $_.Name -like "*NDP472*" })) {
                Write-Host "Installing .Net Framework 4.7.2 ..."
                Start-Sleep -Seconds 5
            }

            Write-Host ".Net Framework 4.7.2 was installed successfully!" -ForegroundColor Green

            write-Host ""

            #Restart computer once the DotNET was installed:

            Write-Warning "You MUST restart computer $env:ComputerName in order to use .Net Framework 4.7.2! Please do so at your earliest convenience."
            $restartcomputer = Read-Host "Do you want to restart your computer now? (Y\N)"
    
       
            If ($restartcomputer -eq "y") { 
                Write-Host ""
                Write-Host "After the restart is complete, run again this script"
                Write-Host ""
                Write-Host "Waiting for 10 seconds and restarting this computer..."
                Start-Sleep -Seconds 10
                Restart-Computer -Force
            }
      
   
            elseif ($restartcomputer -eq "n") { 
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

        #Install Az Module of necessary:
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

        $error.clear()
        Try {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Get-ItemProperty -Path $AdminKey -Name "IsInstalled" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | out-null
        }
        catch {}

        if (!$error)
        {
        $CheckIfInternetExplorerEnhancedSecurityEnabledOrDisabled = (Get-ItemProperty -Path $AdminKey -Name "IsInstalled").IsInstalled #1= enabled - 0=disabled
        If ($CheckIfInternetExplorerEnhancedSecurityEnabledOrDisabled -eq "1") {
            Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
            Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
            Stop-Process -Name Explorer -Force
            Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
        }
        elseif ($CheckIfInternetExplorerEnhancedSecurityEnabledOrDisabled -eq "0") { Write-Host "IE Enhanced Security Configuration (ESC) is disabled." -ForegroundColor Green }


        Write-host ""

        }
        if ($error)
            {Write-host ""
            Write-host "Internet explorer is not installed. Skipping to disable Internet Explorer Enhanced Security "
            }
        }

    function Get-SecretFromKV {

        # Retrieving the .BEK file from the Key vault

        #Get current logged in user and active directory tenant details:
        $ctx = Get-AzContext;
        $adTenant = $ctx.Tenant.Id;
        $currentUser = $ctx.Account.Id

        # Disk is Managed

        #Get Secret Url and KEK Url - For Single Pass Managed disks:


        #Get Disk RG Name:
        [String]$DiskRGName = (Get-AzResource -Name $DiskName).ResourceGroupName

        #Get Disk properties:
        $Disk = Get-AzDisk -ResourceGroupName $DiskRGName -Name $DiskName;


        #Get Secret Url, KeyVault Name, KEK Url and Secret Name - For Single Pass Managed disks: -> This does not work for dual pass since the encryption settings are not stored at disk level, only at VM level.

        #first, clear all previous errors
        $error.clear()

        try {
            $secretUrl = $Disk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SecretUrl
            #Parse the secret URI and KEK URL:
            $secretUri = [System.Uri] $secretUrl;
            $keyVaultName = $secretUri.Host.Split('.')[0];
            $secretName = $secretUri.Segments[2].TrimEnd('/')
            if (!$secretVersion)
            {$secretVersion = $secretUri.Segments[3].TrimEnd('/');}

        }
        catch {
        }

        #Check if the selected managed disk has encryption settings:

        if (!$error)
        { 

        #Creating Working path:
        Write-Host " "
        Write-Host "Checking if the work directory exist and if not, creating work directory c:\GetSecret... "
        Write-Host " "
        #Set\Created path for secret to be written:
        $path = "C:\GetSecret\Disks\$DiskName\SecretName\$secretName\SecretVersions\$secretVersion\"

        # if the path does not exist, create the folders:

        If (!(test-path $path)) {$newdirectory = New-Item -ItemType Directory -Force -Path $path -WarningAction:SilentlyContinue}

         
         #check if is BEK or KEK   
         $KeKUrl = $Disk.EncryptionSettingsCollection.EncryptionSettings.KeyEncryptionKey.KeyURL

            #List Encryption settings of the managed disk selected:
             
            if ($KeKUrl -eq $null) {

            #List Encryption settings of the managed disk selected:
            Write-host ""
            Write-host "=============================================================================================================================================="
            Write-host "Selected managed disk is encrypted with Single Pass using BEK" -ForegroundColor green
            Write-host "=============================================================================================================================================="
            write-host ""
            write-host "Encryption settings:" -ForegroundColor Cyan
            write-host ""
            Write-host "Key Vault name: $keyVaultName" 
            Write-host "Secret Name: $secretName"
            Write-Host "Secret Version: $secretVersion"
            Write-host "Secret URL: $secretUrl"
            Write-Host "KEK Name: "
            Write-Host "KEK Version: "
            Write-host "KEK URL:" 
            write-host ""
            Write-host "=============================================================================================================================================="

            #write Encryption settings to file for troubleshooting purposes

            $EncryptionSettingsFilePath = $path + "\EncryptionSetting" + ".txt"
            If (!(test-path $EncryptionSettingsFilePath)) {$newfile = New-Item -Path $EncryptionSettingsFilePath -WarningAction:SilentlyContinue}

            write-output "----------------------------------------------------------------------------------------------------------------------------------------------" >> $EncryptionSettingsFilePath
            Get-Date >> $EncryptionSettingsFilePath
            write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            Write-output "Selected managed disk is encrypted with Single Pass using BEK" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            write-output "Encryption settings:" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "Key Vault name: $keyVaultName" >> $EncryptionSettingsFilePath
            Write-output "Secret Name: $secretName" >> $EncryptionSettingsFilePath
            Write-output "Secret Version: $secretVersion" >> $EncryptionSettingsFilePath
            Write-output "Secret URL: $secretUrl" >> $EncryptionSettingsFilePath
            Write-output "KEK Name: " >> $EncryptionSettingsFilePath
            Write-output "KEK Version: " >> $EncryptionSettingsFilePath
            Write-output "KEK URL:"  >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath

            write-host ""
            write-host "Encryption settings were also saved to a text file in to the working directory"
            write-host ""
            } 

            elseif ($KeKUrl -ne $null) {

            #get KEK name and version
            $KekName = $KeKUrl.Split('/')[4]

            if (!$KekVersion)
            {$KekVersion = $KeKUrl.Split('/')[5]}

            #List Encryption settings of the managed disk selected:
            Write-host ""
            Write-host "=============================================================================================================================================="
            Write-host "Selected managed disk is encrypted with Single Pass using KEK" -ForegroundColor green
            Write-host "=============================================================================================================================================="
            write-host ""
            write-host "Encryption settings:" -ForegroundColor Cyan
            write-host ""
            Write-host "Key Vault name: $keyVaultName" 
            Write-host "Secret Name: $secretName"
            Write-Host "Secret Version: $secretVersion"
            Write-host "Secret URL: $secretUrl"
            Write-Host "KEK Name: $KekName"
            Write-Host "KEK Version: $KekVersion"
            Write-host "KEK URL: $KeKUrl" 
            write-host ""
            Write-host "=============================================================================================================================================="

             #write Encryption settings to file for troubleshooting purposes

            $EncryptionSettingsFilePath = $path + "\EncryptionSetting" + ".txt"
            If (!(test-path $EncryptionSettingsFilePath)) {$newfile = New-Item -Path $EncryptionSettingsFilePath -WarningAction:SilentlyContinue}

            write-output "----------------------------------------------------------------------------------------------------------------------------------------------" >> $EncryptionSettingsFilePath
            Get-Date >> $EncryptionSettingsFilePath
            write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            Write-output "Selected managed disk is encrypted with Single Pass using KEK" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            write-output "Encryption settings:" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "Key Vault name: $keyVaultName" >> $EncryptionSettingsFilePath
            Write-output "Secret Name: $secretName" >> $EncryptionSettingsFilePath
            Write-output "Secret Version: $secretVersion" >> $EncryptionSettingsFilePath
            Write-output "Secret URL: $secretUrl" >> $EncryptionSettingsFilePath
            Write-output "KEK Name: $KekName" >> $EncryptionSettingsFilePath
            Write-output "KEK Version: $KekVersion " >> $EncryptionSettingsFilePath
            Write-output "KEK URL: $KeKUrl"  >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath

            write-host ""
            write-host "Encryption settings were also saved to a text file in to the working directory"
            write-host ""

            }
        }


        if ($error) { #encryption settings were NOT found

            #List encryption settings:
            Write-host "=============================================================================================================================================="
            Write-host "No encryption settings were found for the selected managed disk, or the selected managed disk was encrypted with Dual Pass" -ForegroundColor Red
            Write-host "=============================================================================================================================================="
            write-host ""
            write-host "Encryption settings:" -ForegroundColor Cyan
            write-host ""
            Write-host "Key Vault name: $keyVaultName" 
            Write-host "Secret Name: $secretName"
            Write-Host "Secret Version: $secretVersion"
            Write-host "Secret URL: $secretUrl"
            Write-Host "KEK Name: $KekName"
            Write-Host "KEK Version: $KekVersion"
            Write-host "KEK URL: $KeKUrl" 
            write-host ""
            Write-host "=============================================================================================================================================="
            write-host ""
            Write-host "If the managed disk was encrypted with Dual Pass, this is not supported" -ForegroundColor Yellow
            write-host ""
            Write-Host "Script will exit in 30 seconds"
            Start-Sleep -Seconds 30
            Exit
        }





        ######################################################
        #      Check Permissions on secrets and keys        #
        ######################################################


        # Check what is the permission model for the Key Vault (Access policy or RBAC)

        $AccessPoliciesOrRBAC = (Get-AzKeyVault -VaultName $keyVaultName).EnableRbacAuthorization



        # If EnableRbacAuthorization is false, that means the permission model is based on Access Policies and we will attempt to set permissions. If this fails, permissions needs to be granted manually by user.

        if ($AccessPoliciesOrRBAC -eq $false) {
            Write-Host ""
            Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Access policy.'" -ForegroundColor Cyan
            Write-Host ""

            #Get Current user permissions to keys and secrets
            write-host "Checking permissions to keys and secrets from key vault '$keyVaultName' for user '$currentUser'..."
            write-host ""
            $CurrentUserPermissionsToKeys = ((Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies | ? { $_.DisplayName -like "*$currentUser*" }).PermissionsToKeys
            $CurrentUserPermissionsToSecrets = ((Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies | ? { $_.DisplayName -like "*$currentUser*" }).PermissionsToSecrets

            #Verify permissions if curent user has at least 'list' and 'unwrapkey' or "All" permissions to keys and 'get' and 'list' or "All" permissions to secrets from Key Vault

            if (($CurrentUserPermissionsToKeys -eq "all") -or ($CurrentUserPermissionsToKeys -eq "list" -and $CurrentUserPermissionsToKeys -eq "unwrapkey")) {
            
                Write-Host "User has the proper permissions to Keys in the key vault (either 'All' or 'list' and 'unwrapkey')" -ForegroundColor Green
                Write-Host "Permissions to Keys for user '$currentUser' are: $CurrentUserPermissionsToKeys"
                Write-Host ""
            }

    
            else {                                                                                                                                                  
                Write-Host "User does not have the proper permissions to Keys in the key vault (either 'All' or 'list' and 'unwrapkey')" -ForegroundColor Yellow
                Write-Host "Permissions to Keys for user '$currentUser' are: $CurrentUserPermissionsToKeys"
                Write-Host ""
                Write-Host "Script will set the following permissions to Keys: list,unwrapkey for user '$currentUser'"

                # Set for current permissions To Keys "List" and "unwrapkey"
                $error.clear()

                try { Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys list, unwrapkey -UserPrincipalName $currentUser -ErrorAction Stop }

                catch {

                    Write-Host ""
                    Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
                    Write-Host -Foreground Red -Background Black ($Error[0])
                    Write-Host ""
                }

                # if there is not error on the set permission operation, permissions were set successfully
                if (!$error) {
                    Write-Host ""
                    Write-Host "DONE! -> Permissions 'list,unwrapkey' were set for user '$currentUser' on the keys from the key vault '$keyVaultName'" -ForegroundColor green
                    Write-Host ""
                }

                # if there is an error on the set permission operation, permissions were NOT set successfully
                if ($error) {
                    Write-Host ""
                    Write-Warning "Permissions 'list,unwrapkey' permissions could NOT be set for user '$currentUser'"
                    Write-Host ""
                    Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow

                    # Get Object Id of your Azure AD user
                    Write-Host ""
                    Write-Host "Conclusion: Your user does not have access to the keys and secrets from Key Vault '$keyVaultName' and also cannot grant itself permissions" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "If you do not have access to that section, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault '$keyVaultName' and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
                    Write-Host ""
                }
            }
        

            if (($CurrentUserPermissionsToSecrets -eq "all") -or ($CurrentUserPermissionsToSecrets -eq "list" -and $CurrentUserPermissionsToSecrets -eq "get")) {           
     
                Write-Host "User has the proper permissions to Secrets in the key vault (either 'All' or 'list' and 'get')" -ForegroundColor Green
                Write-Host "Permissions to Secrets for user '$currentUser' are: $CurrentUserPermissionsToSecrets"
                Write-Host ""
            }

            else {                                                                                                                                                      
                Write-Host "User does not have the proper permissions to Secrets in the key vault (either 'All' or 'list' and 'het')" -ForegroundColor Yellow
                Write-Host "Permissions to Secrets for user '$currentUser' are: $CurrentUserPermissionsToSecrets"
                Write-Host ""
                Write-Host "Script will set the following permissions to Secrets: list,get for user '$currentUser'"

                # Set for current permissions To Secrets "List" and "Get"
                $error.clear()

                try { Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToSecrets list, get -UserPrincipalName $currentUser -ErrorAction Stop }

                catch {

                    Write-Host ""
                    Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
                    Write-Host -Foreground Red -Background Black ($Error[0])
                    Write-Host ""
                }

                # if there is not error on the set permission operation, permissions were set successfully
                if (!$error) {
                    Write-Host ""
                    Write-Host "DONE! -> Permissions 'list,get' were set for user '$currentUser' on the secrets from the key vault '$keyVaultName'" -ForegroundColor green
                    Write-Host ""
                }

                # if there is an error on the set permission operation, permissions were NOT set successfully
                if ($error) {
                    Write-Host ""
                    Write-Warning "Permissions 'list,get' permissions could NOT be set for user '$currentUser'"
                    Write-Host ""
                    Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow

                    # Get Object Id of your Azure AD user
                    Write-Host ""
                    Write-Host "Conclusion: Your user does not have access to the keys and secrets from Key Vault '$keyVaultName' and also cannot grant itself permissions" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "If you do not have access to that section, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault '$keyVaultName' and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
                    Write-Host ""
                }
            }
        }

        #If EnableRbacAuthorization is true, that means the permission model is based on RBAC and we will not attempt to set permissions. Permissions needs to be granted manually by user.

        if ($AccessPoliciesOrRBAC -eq $true) {
            Write-Host ""
            Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Azure role-based access control (RBAC)'." -ForegroundColor Cyan
            Write-Host ""

            #check if user already 'Key Vault Administrator' or 'Contributor' or 'Owner' roles assigned
            Write-Host "Checking if user '$currentUser' has the role 'Key Vault Administrator' on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret
            $KeyVaultScope = $Disk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SourceVault.id
            $UserHasRoleKeyVaultAdministrator = (Get-AzRoleAssignment -Scope $KeyVaultScope | ? { ($_.RoleDefinitionName -eq "Key Vault Administrator") -and ($_.SignInName -eq $currentUser) }).RoleDefinitionName

            if ($UserHasRoleKeyVaultAdministrator -eq $null) {
                #set permissions:
                Write-Host ""
                Write-Host "User: $currentUser does not have the role 'Key Vault Administrator' on Keyvault '$keyVaultName'"
                Write-Host ""
                Write-Host "User '$currentUser' has '$UserHasRoleKeyVaultAdministrator' role"
                Write-Host ""
                Write-Host "Assigning 'Key Vault Administrator' role for user: $currentUser on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret

                $error.clear()
                try { New-AzRoleAssignment -SignInName $currentUser -RoleDefinitionName "Key Vault Administrator" -Scope $KeyVaultScope | Out-Null }

                catch {

                    Write-Host ""
                    Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
                    Write-Host -Foreground Red -Background Black ($Error[0])
                    Write-Host ""
                }

                # if there is not error on the set permission operation, permissions were set successfully
                if (!$error) {
                    Write-Host ""
                    Write-Host "'Key Vault Administrator' role was assigned for user: $currentUser on Keyvault '$keyVaultName'" -ForegroundColor green
                    Write-Host "" 
                }

                # if there is an error on the set permission operation, permissions were NOT set successfully
                if ($error) {
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
                    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault $keyVaultName and assign 'Contributor' role for your user and then run again the script" -ForegroundColor yellow
                    Write-Host ""
                }
            }
            if ($UserHasRoleKeyVaultAdministrator -ne $null) {
                Write-Host ""
                Write-Host "User '$currentUser' has '$UserHasRoleKeyVaultAdministrator' role which meets requirements!" -ForegroundColor Green
                Write-Host "" 
            }
        }

        #############################
        #Scenario where BEK was used:
        #############################

        if ($KeKUrl -eq $null) # if $kekurl is $null, then only BEK was used
        {
            #===========================================
            # Write to console output the BEK file selected
            Write-Host " "
            Write-Host "The BEK secret name '$secretName', version '$secretVersion' was found and will be used." -ForegroundColor Green
            Write-Host ""


            #===========================================
            #Formatting the full path name of the .bek file that will be save to disk
            $bekFilePath = $path + "\$secretName" + ".BEK"

            #=========================
            # New method retrieve the secret value of the secret-> https://stackoverflow.com/questions/63732583/warning-about-breaking-changes-in-the-cmdlet-get-azkeyvaultsecret-secretvaluet

            $error.clear()
            try{$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Version $secretVersion -ErrorAction SilentlyContinue}
            catch {}
            if ($error){
            Write-Host "There was an error in getting the secret with name '$secretName', version '$secretVersion' from Key Vault '$keyVaultName'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Verify that the secret name, secret version and Key Vault name are correct"
            Write-Host ""
            Write-Host "Script will exit in 30 seconds"
            Start-Sleep -Seconds 30
            }

            $secretValueText = '';
            $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
            try {
                $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
            }


            #===========================================
            # Downloading the BEK from the KV to disk (path)

            Write-Host "Writing BEK to disk.."
            Write-Host ""
            $bekSecretBase64 = $secretValueText
            #Convert base64 string to bytes and write to BEK file
            $bekFileBytes = [System.Convert]::FromBase64String($bekSecretBase64);
            $bekFileBytes = [Convert]::FromBase64String($bekSecretbase64) #other method
            [System.IO.File]::WriteAllBytes($bekFilePath, $bekFileBytes)

            Write-Host ""
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host "The secret was saved under path: $bekFilePath" 
            Write-Host "==========================================================================================================================================================================================================================="

            #================================================
            #start the unlocking process
            Write-Host " "
            Write-Host "Starting the unlock process..." 
            Write-Host " "
            #===========================================
            # Checking how many online encrypted disks are on this VM.If only one, we will store automatically the drive letter and use it to unlock the disk. If more than one, we need the drive letter specified manually
            $numberOfEncryptedDisksFound = (Get-BitLockerVolume | ? { $_.KeyProtector -ne $null }).count

            if ($numberOfEncryptedDisksFound -eq 1) {
                Write-Host ""
                Write-Host "One encrypted disk set as 'Online' was found attached to this VM. It will automatically be unlocked" -ForegroundColor Cyan
                Write-Host ""
                $DriveLetterOfDiskToUnlock = (Get-BitLockerVolume | ? { $_.KeyProtector -ne $null }).mountpoint
            }

            if ($numberOfEncryptedDisksFound -gt 1) {
                Write-Host ""
                Write-Host "More than one encrypted disk set as 'Online' was found attached to this VM" -ForegroundColor Yellow
                Write-Host ""
                #Select the drive letter of the attached disk you want to unlock
                $DriveLetterOfDiskToUnlock = Read-Host "Select the drive letter of the disk that is attached to this current VM that you want to unlock (Ex: F:) "
            }
            Write-Host " "
            Write-Host "Unlocking the disk... "  -ForegroundColor "Cyan"
            Write-Host " "

            #===========================================
            #Unlocking the disk using the BEK that was just downloaded from the KV
            manage-bde -unlock $DriveLetterOfDiskToUnlock -RecoveryKey $BekFilePath
            Write-Host " "
            Write-Host "DONE!"  -ForegroundColor "Green"

            #===========================================
            #Open Unlocked drive
            explorer.exe $DriveLetterOfDiskToUnlock
            Write-Host ""
            Write-Host "$DriveLetterOfDiskToUnlock drive was opened in Windows Explorer" 
            Write-Host ""
            #================================================
        }

        ###########################################
        #Scenario where KEK was used (wrapped BEK):
        ###########################################

        elseif ($KeKUrl -ne $null) { # if $kekurl is NOT $null, then the BEK is wrapped (KEK)
            $KekFilePath = $path + "\$secretName" + ".BEK"
            Write-Host "The wrapped BEK (KEK) secret name '$secretName', version '$secretVersion' was found and will be used." -ForegroundColor Green
            Write-Host " "
            #Retrieve secret from KeyVault secretUrl
            
            $error.clear()
            try{$keyVaultSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Version $secretVersion -ErrorAction SilentlyContinue}
            catch {}
            if ($error){
            Write-Host "There was an error in getting the secret with name '$secretName', version '$secretVersion' from Key Vault '$keyVaultName'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Verify that the secret name, secret version and Key Vault name are correct"
            Write-Host ""
            Write-Host "Script will exit in 30 seconds"
            Start-Sleep -Seconds 30
            }


            $secretBase64 = $keyVaultSecret.SecretValue;
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretBase64)
            $secretBase64 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

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

            $unwrapKeyRequestUrl = $kekUrl + "/unwrapkey?api-version=2015-06-01";
            $result = Invoke-RestMethod -Method POST -Uri $unwrapKeyRequestUrl -Headers $headers -Body $jsonObject -ContentType "application/json";

            #Convert Base64Url string returned by KeyVault unwrap to Base64 string
            $secretBase64 = $result.value;

            $secretBase64 = $secretBase64.Replace('-', '+');
            $secretBase64 = $secretBase64.Replace('_', '/');
            if ($secretBase64.Length % 4 -eq 2) {
                $secretBase64 += '==';
            }
            elseif ($secretBase64.Length % 4 -eq 3) {
                $secretBase64 += '=';
            }

            if ($KekFilePath) {
                Write-Host " "
                Write-Host "Writing wrapped BEK (KEK) to disk.."
                $bekFileBytes = [System.Convert]::FromBase64String($secretBase64);
                [System.IO.File]::WriteAllBytes($KekFilePath, $bekFileBytes);
            }

            Write-Host ""
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host "The secret was saved under path: $KekFilePath"
            Write-Host "==========================================================================================================================================================================================================================="


            #===========================================
            #Delete the key from the memory
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            clear-variable -name secretBase64

            #================================================
            #start the unlocking process
            Write-Host " "
            Write-Host "Starting the unlock process... "
            Write-Host " "
            # Checking how many online encrypted disks are on this VM.If only one, we will store automatically the drive letter and use it to unlock the disk. If more than one, we need the drive letter specified manually
            $numberOfEncryptedDisksFound = (Get-BitLockerVolume | ? { $_.KeyProtector -ne $null }).count

            if ($numberOfEncryptedDisksFound -eq 1) {
                Write-Host ""
                Write-Host "One encrypted disk set as 'Online' was found attached to this VM. It will automatically be unlocked" -ForegroundColor Cyan
                Write-Host ""
                $DriveLetterOfDiskToUnlock = (Get-BitLockerVolume | ? { $_.KeyProtector -ne $null }).mountpoint
            }

            if ($numberOfEncryptedDisksFound -gt 1) {
                Write-Host ""
                Write-Host "More than one encrypted disk set as 'Online' was found attached to this VM" -ForegroundColor Yellow
                Write-Host ""
                #Select the drive letter of the attached disk you want to unlock
                $DriveLetterOfDiskToUnlock = Read-Host "Select the drive letter of the disk that is attached to this current VM that you want to unlock (Ex: F:) "
            }
            Write-Host " "
            Write-Host "Unlocking the disk... "  -ForegroundColor "Cyan"
            Write-Host " "

            #===========================================
            #Unlocking the disk using the BEK that was just downloaded from the KV
            manage-bde -unlock $DriveLetterOfDiskToUnlock -RecoveryKey $KekFilePath
            Write-Host " "
            Write-Host "DONE!"  -ForegroundColor "Green"

            #===========================================
            #Open Unlocked drive
            explorer.exe $DriveLetterOfDiskToUnlock
            Write-Host ""
            Write-Host "$DriveLetterOfDiskToUnlock drive was opened in Windows Explorer"
            Write-Host ""
            #================================================
        }
        #=========================================================
    }


    #============================================End of Functions definition================================================

    #Starting the script:

    Prerequisites

    Authentication

    Get-SecretFromKV
}

if ($Mode -eq "cloudshell") {
    #######################################
    #       Connect to Az Account        #
    #######################################

    if($UseDeviceAuthentication)
    {
    Connect-AzAccount -UseDeviceAuthentication
    }

    Set-AzContext -Subscription $subscriptionId | out-null

    Write-Host""
    Write-Host "Subscription with ID '$subscriptionId' was selected"
    Write-Host""


    function Get-SecretFromKV {

        # Retrieving the .BEK file from the Key vault

        #Get current logged in user and active directory tenant details:
        $ctx = Get-AzContext;
        $adTenant = $ctx.Tenant.Id;
        $currentUser = $ctx.Account.Id

        # Disk is Managed

        #Get Secret Url and KEK Url - For Single Pass Managed disks:

        #Get Disk RG Name:
        $DiskRGName = (Get-AzResource -Name $DiskName).ResourceGroupName

        #Get Disk properties:
        $Disk = Get-AzDisk -ResourceGroupName $DiskRGName -Name $DiskName;

        #Get Secret Url, KeyVault Name, KEK Url and Secret Name - For Single Pass Managed disks: -> This does not work for dual pass since the encryption settings are not stored at disk level, only at VM level.

        #first, clear all previous errors
        $error.clear()

        try {
            $secretUrl = $Disk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SecretUrl
            #Parse the secret URI and KEK URL:
            $secretUri = [System.Uri] $secretUrl;
            $keyVaultName = $secretUri.Host.Split('.')[0];
            $secretName = $secretUri.Segments[2].TrimEnd('/')
            if (!$secretVersion)
            {$secretVersion = $secretUri.Segments[3].TrimEnd('/');}

        }
        catch {
        }

        #Check if the selected managed disk has encryption settings:

        if (!$error) 
        { #encryption settings were found

        #Creating Working path:
        Write-Host " "
        Write-Host "Checking if the work directory exist and if not, creating work directory c:\GetSecret... "
        Write-Host " "
        #Set\Created path for secret to be written:
        $path = "$HOME/GetSecret/Disks/$DiskName/SecretName/$secretName/SecretVersions/$secretVersion"

        # if the path does not exist, create the folders:

        If (!(test-path $path)) {$newdirectory = New-Item -ItemType Directory -Force -Path $path -WarningAction:SilentlyContinue}

         
         #check if is BEK or KEK   
         $KeKUrl = $Disk.EncryptionSettingsCollection.EncryptionSettings.KeyEncryptionKey.KeyURL

            #List Encryption settings of the managed disk selected:
             
            if ($KeKUrl -eq $null) {

            #List Encryption settings of the managed disk selected:
            Write-host ""
            Write-host "=============================================================================================================================================="
            Write-host "Selected managed disk is encrypted with Single Pass using BEK" -ForegroundColor green
            Write-host "=============================================================================================================================================="
            write-host ""
            write-host "Encryption settings:" -ForegroundColor Cyan
            write-host ""
            Write-host "Key Vault name: $keyVaultName" 
            Write-host "Secret Name: $secretName"
            Write-Host "Secret Version: $secretVersion"
            Write-host "Secret URL: $secretUrl"
            Write-Host "KEK Name: "
            Write-Host "KEK Version: "
            Write-host "KEK URL:" 
            write-host ""
            Write-host "=============================================================================================================================================="

            #write Encryption settings to file for troubleshooting purposes

            $EncryptionSettingsFilePath = $path + "/EncryptionSetting" + ".txt"
            If (!(test-path $EncryptionSettingsFilePath)) {$newfile = New-Item -Path $EncryptionSettingsFilePath -WarningAction:SilentlyContinue}

            write-output "----------------------------------------------------------------------------------------------------------------------------------------------" >> $EncryptionSettingsFilePath
            Get-Date >> $EncryptionSettingsFilePath
            write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            Write-output "Selected managed disk is encrypted with Single Pass using BEK" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            write-output "Encryption settings:" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "Key Vault name: $keyVaultName" >> $EncryptionSettingsFilePath
            Write-output "Secret Name: $secretName" >> $EncryptionSettingsFilePath
            Write-output "Secret Version: $secretVersion" >> $EncryptionSettingsFilePath
            Write-output "Secret URL: $secretUrl" >> $EncryptionSettingsFilePath
            Write-output "KEK Name: " >> $EncryptionSettingsFilePath
            Write-output "KEK Version: " >> $EncryptionSettingsFilePath
            Write-output "KEK URL:"  >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath

            write-host ""
            write-host "Encryption settings were also saved to a text file in to the working directory"
            write-host ""
            } 

            elseif ($KeKUrl -ne $null) {

            #get KEK name and version
            $KekName = $KeKUrl.Split('/')[4]

            if (!$KekVersion)
            {$KekVersion = $KeKUrl.Split('/')[5]}

            #List Encryption settings of the managed disk selected:
            Write-host ""
            Write-host "=============================================================================================================================================="
            Write-host "Selected managed disk is encrypted with Single Pass using KEK" -ForegroundColor green
            Write-host "=============================================================================================================================================="
            write-host ""
            write-host "Encryption settings:" -ForegroundColor Cyan
            write-host ""
            Write-host "Key Vault name: $keyVaultName" 
            Write-host "Secret Name: $secretName"
            Write-Host "Secret Version: $secretVersion"
            Write-host "Secret URL: $secretUrl"
            Write-Host "KEK Name: $KekName"
            Write-Host "KEK Version: $KekVersion"
            Write-host "KEK URL: $KeKUrl" 
            write-host ""
            Write-host "=============================================================================================================================================="

            #write Encryption settings to file for troubleshooting purposes

            $EncryptionSettingsFilePath = $path + "/EncryptionSetting" + ".txt"
            If (!(test-path $EncryptionSettingsFilePath)) {$newfile = New-Item -Path $EncryptionSettingsFilePath -WarningAction:SilentlyContinue}

            write-output "----------------------------------------------------------------------------------------------------------------------------------------------" >> $EncryptionSettingsFilePath
            Get-Date >> $EncryptionSettingsFilePath
            write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            Write-output "Selected managed disk is encrypted with Single Pass using KEK" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            write-output "Encryption settings:" >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "Key Vault name: $keyVaultName" >> $EncryptionSettingsFilePath
            Write-output "Secret Name: $secretName" >> $EncryptionSettingsFilePath
            Write-output "Secret Version: $secretVersion" >> $EncryptionSettingsFilePath
            Write-output "Secret URL: $secretUrl" >> $EncryptionSettingsFilePath
            Write-output "KEK Name: $KekName" >> $EncryptionSettingsFilePath
            Write-output "KEK Version: $KekVersion " >> $EncryptionSettingsFilePath
            Write-output "KEK URL: $KeKUrl"  >> $EncryptionSettingsFilePath
            write-output "" >> $EncryptionSettingsFilePath
            Write-output "==============================================================================================================================================" >> $EncryptionSettingsFilePath

            write-host ""
            write-host "Encryption settings were also saved to a text file in to the working directory"
            write-host ""

            }
        }


        if ($error) { #encryption settings were NOT found

            #List encryption settings:
            Write-host "=============================================================================================================================================="
            Write-host "No encryption settings were found for the selected managed disk, or the selected managed disk was encrypted with Dual Pass" -ForegroundColor Red
            Write-host "=============================================================================================================================================="
            write-host ""
            write-host "Encryption settings:" -ForegroundColor Cyan
            write-host ""
            Write-host "Key Vault name: $keyVaultName" 
            Write-host "Secret Name: $secretName"
            Write-Host "Secret Version: $secretVersion"
            Write-host "Secret URL: $secretUrl"
            Write-Host "KEK Name: $KekName"
            Write-Host "KEK Version: $KekVersion"
            Write-host "KEK URL: $KeKUrl" 
            write-host ""
            Write-host "=============================================================================================================================================="
            write-host ""
            Write-host "If the managed disk was encrypted with Dual Pass, this is not supported" -ForegroundColor Yellow
            write-host ""
            Write-Host "Script will exit in 30 seconds"
            Start-Sleep -Seconds 30
            Exit
        }





        ######################################################
        #      Check Permissions on secrets and keys        #
        ######################################################


        # Check what is the permission model for the Key Vault (Access policy or RBAC)

        $AccessPoliciesOrRBAC = (Get-AzKeyVault -VaultName $keyVaultName).EnableRbacAuthorization



        # If EnableRbacAuthorization is false, that means the permission model is based on Access Policies and we will attempt to set permissions. If this fails, permissions needs to be granted manually by user.

        if ($AccessPoliciesOrRBAC -eq $false) {
            Write-Host ""
            Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Access policy.'" -ForegroundColor Cyan
            Write-Host ""

            #Get Current user permissions to keys and secrets
            write-host "Checking permissions to keys and secrets from key vault '$keyVaultName' for user '$currentUser'..."
            write-host ""
            $CurrentUserPermissionsToKeys = ((Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies | ? { $_.DisplayName -like "*$currentUser*" }).PermissionsToKeys
            $CurrentUserPermissionsToSecrets = ((Get-AzKeyVault -VaultName $keyVaultName).AccessPolicies | ? { $_.DisplayName -like "*$currentUser*" }).PermissionsToSecrets

            #Verify permissions if curent user has at least 'list' and 'unwrapkey' or "All" permissions to keys and 'get' and 'list' or "All" permissions to secrets from Key Vault

            if (($CurrentUserPermissionsToKeys -eq "all") -or ($CurrentUserPermissionsToKeys -eq "list" -and $CurrentUserPermissionsToKeys -eq "unwrapkey")) {
            
                Write-Host "User has the proper permissions to Keys in the key vault (either 'All' or 'list' and 'unwrapkey')" -ForegroundColor Green
                Write-Host "Permissions to Keys for user '$currentUser' are: $CurrentUserPermissionsToKeys"
                Write-Host ""
            }

    
            else {                                                                                                                                                  
                Write-Host "User does not have the proper permissions to Keys in the key vault (either 'All' or 'list' and 'unwrapkey')" -ForegroundColor Yellow
                Write-Host "Permissions to Keys for user '$currentUser' are: $CurrentUserPermissionsToKeys"
                Write-Host ""
                Write-Host "Script will set the following permissions to Keys: list,unwrapkey for user '$currentUser'"

                # Set for current permissions To Keys "List" and "unwrapkey"
                $error.clear()

                try { Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToKeys list, unwrapkey -UserPrincipalName $currentUser -ErrorAction Stop }

                catch {

                    Write-Host ""
                    Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
                    Write-Host -Foreground Red -Background Black ($Error[0])
                    Write-Host ""
                }

                # if there is not error on the set permission operation, permissions were set successfully
                if (!$error) {
                    Write-Host ""
                    Write-Host "DONE! -> Permissions 'list,unwrapkey' were set for user '$currentUser' on the keys from the key vault '$keyVaultName'" -ForegroundColor green
                    Write-Host ""
                }

                # if there is an error on the set permission operation, permissions were NOT set successfully
                if ($error) {
                    Write-Host ""
                    Write-Warning "Permissions 'list,unwrapkey' permissions could NOT be set for user '$currentUser'"
                    Write-Host ""
                    Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow

                    # Get Object Id of your Azure AD user
                    Write-Host ""
                    Write-Host "Conclusion: Your user does not have access to the keys and secrets from Key Vault '$keyVaultName' and also cannot grant itself permissions" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "If you do not have access to that section, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault '$keyVaultName' and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
                    Write-Host ""
                }
            }
        

            if (($CurrentUserPermissionsToSecrets -eq "all") -or ($CurrentUserPermissionsToSecrets -eq "list" -and $CurrentUserPermissionsToSecrets -eq "get")) {           
     
                Write-Host "User has the proper permissions to Secrets in the key vault (either 'All' or 'list' and 'get')" -ForegroundColor Green
                Write-Host "Permissions to Secrets for user '$currentUser' are: $CurrentUserPermissionsToSecrets"
                Write-Host ""
            }

            else {                                                                                                                                                      
                Write-Host "User does not have the proper permissions to Secrets in the key vault (either 'All' or 'list' and 'het')" -ForegroundColor Yellow
                Write-Host "Permissions to Secrets for user '$currentUser' are: $CurrentUserPermissionsToSecrets"
                Write-Host ""
                Write-Host "Script will set the following permissions to Secrets: list,get for user '$currentUser'"

                # Set for current permissions To Secrets "List" and "Get"
                $error.clear()

                try { Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -PermissionsToSecrets list, get -UserPrincipalName $currentUser -ErrorAction Stop }

                catch {

                    Write-Host ""
                    Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
                    Write-Host -Foreground Red -Background Black ($Error[0])
                    Write-Host ""
                }

                # if there is not error on the set permission operation, permissions were set successfully
                if (!$error) {
                    Write-Host ""
                    Write-Host "DONE! -> Permissions 'list,get' were set for user '$currentUser' on the secrets from the key vault '$keyVaultName'" -ForegroundColor green
                    Write-Host ""
                }

                # if there is an error on the set permission operation, permissions were NOT set successfully
                if ($error) {
                    Write-Host ""
                    Write-Warning "Permissions 'list,get' permissions could NOT be set for user '$currentUser'"
                    Write-Host ""
                    Write-Host "Most probably your Azure AD (AAD) account has limited access or is external to AAD" -ForegroundColor yellow

                    # Get Object Id of your Azure AD user
                    Write-Host ""
                    Write-Host "Conclusion: Your user does not have access to the keys and secrets from Key Vault '$keyVaultName' and also cannot grant itself permissions" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "To try and give permission to your user, you will be asked to type the object ID of your Azure AD user. This can be found in Azure portal -> Azure Active Directory -> Users -> Search for your user -> Profile." -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "If you do not have access to that section, ask an Azure Active Directory admin to give you the object ID of your Azure AD user" -ForegroundColor yellow
                    Write-Host ""
                    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault '$keyVaultName' and to create a KeyVault Access Policy to grant 'list' and 'unwrapkey' permissions to keys and 'get' and 'list' permissions to secrets for your user and then run again the script" -ForegroundColor yellow
                    Write-Host ""
                }
            }
        }

        #If EnableRbacAuthorization is true, that means the permission model is based on RBAC and we will not attempt to set permissions. Permissions needs to be granted manually by user.

        if ($AccessPoliciesOrRBAC -eq $true) {
            Write-Host ""
            Write-host "Permission model on the Key Vault '$keyVaultName' is based on 'Azure role-based access control (RBAC)'." -ForegroundColor Cyan
            Write-Host ""

            #check if user already 'Key Vault Administrator' or 'Contributor' or 'Owner' roles assigned
            Write-Host "Checking if user '$currentUser' has the role 'Key Vault Administrator' on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret
            $KeyVaultScope = $Disk.EncryptionSettingsCollection.EncryptionSettings.DiskEncryptionKey.SourceVault.id
            $UserHasRoleKeyVaultAdministrator = (Get-AzRoleAssignment -Scope $KeyVaultScope | ? { ($_.RoleDefinitionName -eq "Key Vault Administrator") -and ($_.SignInName -eq $currentUser) }).RoleDefinitionName

            if ($UserHasRoleKeyVaultAdministrator -eq $null) {
                #set permissions:
                Write-Host ""
                Write-Host "User: $currentUser does not have the role 'Key Vault Administrator' on Keyvault '$keyVaultName'"
                Write-Host ""
                Write-Host "User '$currentUser' has '$UserHasRoleKeyVaultAdministrator' role"
                Write-Host ""
                Write-Host "Assigning 'Key Vault Administrator' role for user: $currentUser on Keyvault '$keyVaultName'..." #if only BEK is used, permission needs to be set only on secret

                $error.clear()
                try { New-AzRoleAssignment -SignInName $currentUser -RoleDefinitionName "Key Vault Administrator" -Scope $KeyVaultScope | Out-Null }

                catch {

                    Write-Host ""
                    Write-Host -Foreground Red -Background Black "Oops, ran into an issue:"
                    Write-Host -Foreground Red -Background Black ($Error[0])
                    Write-Host ""
                }

                # if there is not error on the set permission operation, permissions were set successfully
                if (!$error) {
                    Write-Host ""
                    Write-Host "'Key Vault Administrator' role was assigned for user: $currentUser on Keyvault '$keyVaultName'" -ForegroundColor green
                    Write-Host "" 
                }

                # if there is an error on the set permission operation, permissions were NOT set successfully
                if ($error) {
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
                    Write-Host "Another option would be that the admin to go to Azure Portal -> Key Vaults -> Select KeyVault $keyVaultName and assign 'Contributor' role for your user and then run again the script" -ForegroundColor yellow
                    Write-Host ""
                }
            }
            if ($UserHasRoleKeyVaultAdministrator -ne $null) {
                Write-Host ""
                Write-Host "User '$currentUser' has '$UserHasRoleKeyVaultAdministrator' role which meets requirements!" -ForegroundColor Green
                Write-Host "" 
            }
        }

        #############################
        #Scenario where BEK was used:
        #############################

        if ($KeKUrl -eq $null) # if $kekurl is $null, then only BEK was used
        {
            #===========================================
            # Write to console output the BEK file selected
            Write-Host " "
            Write-Host "The BEK secret name '$secretName', version '$secretVersion' was found and will be used." -ForegroundColor Green
            Write-Host ""


            #===========================================
            #Formatting the full path name of the .bek file that will be save to disk
            $bekFilePath = $path + "/$secretName" + ".BEK"

            #=========================
            # New method retrieve the secret value of the secret-> https://stackoverflow.com/questions/63732583/warning-about-breaking-changes-in-the-cmdlet-get-azkeyvaultsecret-secretvaluet


            $error.clear()
            try{$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Version $secretVersion -ErrorAction SilentlyContinue}
            catch {}
            if ($error){
            Write-Host "There was an error in getting the secret with name '$secretName', version '$secretVersion' from Key Vault '$keyVaultName'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Verify that the secret name, secret version and Key Vault name are correct"
            Write-Host ""
            Write-Host "Script will exit in 30 seconds"
            Start-Sleep -Seconds 30
            }


            $secretValueText = '';
            $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
            try {
                $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
            }


            #===========================================
            # Downloading the BEK from the KV to disk (path)

            Write-Host "Writing BEK to fileshare ..."
            Write-Host ""
            $bekSecretBase64 = $secretValueText
            #Convert base64 string to bytes and write to BEK file
            $bekFileBytes = [System.Convert]::FromBase64String($bekSecretBase64);
            $bekFileBytes = [Convert]::FromBase64String($bekSecretbase64) #other method
            [System.IO.File]::WriteAllBytes($bekFilePath, $bekFileBytes)

            Write-Host " "
            Write-Host "DONE! " -ForegroundColor Green
            Write-Host " "
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host "The secret was saved under path: $bekFilePath" 
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host " "
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host "Download the secret by clicking on 'Click here to download your file' popup window, which is located in the bottom right corner of the page"
            Write-Host "Copy the secret to VM which has the selected encrypted disk attached. Once the secret is on that VM, you need to manually unlock the disk."
            Write-Host "For Windows use manage-bde command like bellow:"
            Write-Host "manage-bde -unlock 'DriveLetterOfDiskToUnlock' -RecoveryKey 'SecretPath' " -ForegroundColor Cyan
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host " "
            download $bekFilePath
            Write-Host " "
            Write-Host " "
        }


        ###########################################
        #Scenario where KEK was used (wrapped BEK):
        ###########################################

        if ($KeKUrl -ne $null) { # if $kekurl is NOT $null, then the BEK is wrapped (KEK)
            $KekFilePath = $path + "/$secretName" + ".BEK"
            Write-Host "The wrapped BEK (KEK) secret name '$secretName', version '$secretVersion' was found and will be used." -ForegroundColor Green
            Write-Host " "

            #Retrieve secret from KeyVault secretUrl


            $error.clear()
            try{$keyVaultSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Version $secretVersion -ErrorAction SilentlyContinue}
            catch {}
            if ($error){
            Write-Host "There was an error in getting the secret with name '$secretName', version '$secretVersion' from Key Vault '$keyVaultName'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Verify that the secret name, secret version and Key Vault name are correct"
            Write-Host ""
            Write-Host "Script will exit in 30 seconds"
            Start-Sleep -Seconds 30
            }


            $secretBase64 = $keyVaultSecret.SecretValue;
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretBase64)
            $secretBase64 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

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

            $unwrapKeyRequestUrl = $kekUrl + "/unwrapkey?api-version=2015-06-01";
            $result = Invoke-RestMethod -Method POST -Uri $unwrapKeyRequestUrl -Headers $headers -Body $jsonObject -ContentType "application/json";

            #Convert Base64Url string returned by KeyVault unwrap to Base64 string
            $secretBase64 = $result.value;

            $secretBase64 = $secretBase64.Replace('-', '+');
            $secretBase64 = $secretBase64.Replace('_', '/');
            if ($secretBase64.Length % 4 -eq 2) {
                $secretBase64 += '==';
            }
            elseif ($secretBase64.Length % 4 -eq 3) {
                $secretBase64 += '=';
            }

            if ($KekFilePath) {
                Write-Host " "
                Write-Host "Writing wrapped BEK (KEK) to fileshare..."
                $bekFileBytes = [System.Convert]::FromBase64String($secretBase64);
                [System.IO.File]::WriteAllBytes($KekFilePath, $bekFileBytes);
            }

            Write-Host " "
            Write-Host "DONE! " -ForegroundColor Green
            Write-Host " "
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host "The secret was saved under path: $KekFilePath"
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host " "
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host "Download the secret by clicking on 'Click here to download your file' popup window, which is located in the bottom right corner of the page"
            Write-Host "Copy the secret to VM which has the selected encrypted disk attached. Once the secret is on that VM, you need to manually unlock the disk."
            Write-Host "For Windows use manage-bde command like bellow:"
            Write-Host "manage-bde -unlock 'DriveLetterOfDiskToUnlock' -RecoveryKey 'SecretPath' " -ForegroundColor Cyan
            Write-Host "==========================================================================================================================================================================================================================="
            Write-Host " "
            download $KekFilePath
            Write-Host " "

            #===========================================
            #Delete the key from the memory
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            clear-variable -name secretBase64

            #================================================

        }
        #=========================================================
    }

    Get-SecretFromKV
}
