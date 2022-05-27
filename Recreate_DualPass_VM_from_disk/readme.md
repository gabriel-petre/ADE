# What is this automated process

This automated process is actually a powershell script

<br />

# Why this automated process was created

<br />

- After the issue was fixed on the copy of the OS disk of a broken VM which was attached to the rescue environment created with script  [**Create_Rescue_VM_from_DualPass_Encrypted_Vm**](https://github.com/gabriel-petre/ADE/tree/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm), the next logical action is to swap the broken OS disk with the fixed copy of OS disk. 
- But the "swap disk" feature is not supported\working on dual pass encrypted VMs
- Since there is no other option than to do the process of replacing the OS disk manually, this process (script) was created to automate the manual process. 

<br />

# Advantages 

- This is an automated process of restoring the functionality of a broken VM after it was fixed for VMs which are encrypted with Dual Pass (older version - with AAD) BEK and KEK
* This powershell script was designed to be used from Azure cloud shell, to eliminate the need of powershell prerequisites needed in the manual process and which caused delays or additional issues due to the diversity of environments in terms of Powershell version, Os version, user permissions, internet connectivity etc.
* The duration for this process using this script is between 4 minutes and 15 minutes (depending on the option selected), which far more less than the manual process which can take hours or even days depending on the complexity of scenarios, environment variables, customer limitations, level of expertise
- Reduced risk of human errors in gathering and using encryption settings
- Available backups in case of the worst scenarios
- The use of the script, has no limitations that were found regarding the operating system versions (Window or Linux) **supported in Azure**
- Offers the possibility to automatically create additional resources or assign necessary permissions needed in this scenario
- Insignificant number of initial input data needed to run this script
- Available execution\troubleshooting logs that can be used to investigate\improve the runtime of this script
- Additional checks during this process to reduce or prevent the risk of a script failure due to the variety of environments
- Additional explanatory details offered during the process, which helps the user to learn also theoretical aspects along the way
- Error handling for the most common errors in terms of auto-resolving or guidance for the manual process of resolving the issue
- Offers the possibility to delete unnecessary resources that were created during the process
- Offers the possibility of using the script multiple times if the troubleshooting scenario requires this, by using the saved VM configuration and backups created in this process

<br />

# Scenarios where ca be used (but not limited to them)

- After the issue was fixed on the copy of the OS disk of a broken VM which was attached to the rescue environment created with script [**Create_Rescue_VM_from_DualPass_Encrypted_Vm**](https://github.com/gabriel-petre/ADE/tree/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm) used this script to recreate the broken VM from a previously exported configuration using fixed copy OS disk
- If in specific troubleshooting scenarios there is the need to delete\create again (recreate) an encrypted dual pass VM from the same OS disk

<br />

# Supported features\scenarios

- VM encrypted with Pass (older version - with AAD) BEK and KEK
- An already deleted VM, can be created from an existing configuration JSON files as long as the other resources are still available (disk, NIC, VNET, NSG, etc..)
- VMs with Managed and Unmanaged disks 
- VMs with Windows\Linux existing operating systems
- This script can be used to delete\recreate an existing encrypted VM with Pass (older version - with AAD) BEK and KEK from the same OS disk
- VMs with multiple data disks
- VMs with multiple NICs
- VMs in an availability set
- VMs in an availability zone
- VMs in an proximity placement group
- VMs in an availability set and in an proximity placement group
- VMs with a plan associated
- VMs with mutiple TAGs
- VMs that have enabled the option "to delete the OS disk when Vm is deleted"  
- VMs that have a 'bootdiagnostics' storage account (managed or custom)

 <br /> 

# Limitations

**Note:**
 <br /> Due to the large variety of options\feature a VM can have, supporting all of them it is a challenge. At this point, please find bellow a limited list of some of the common unsupported options\features.
 <br /> **Unsupported options\features means that they will not be enabled\added automatically. These actions should to be performed manually after VM is recreated**

- The script was designed to be used **only** on VMs which are encrypted with Dual Pass (older version - with AAD)
- The script was designed to be used **only** in [**Azure Cloud Shell**](http://shell.azure.com/)
- Linux VMs that have as an authentication method SSH keys and not passwords are not supported
- VMs that have enabled the option "to delete the data disks or NICs when Vm is deleted"  is not supported
- VMs with other extensions than the ADE extension
- VMs configured to use Azure Recovery Services (like backup or replication)
- VMs with Automatic Updates configured
- VMs with Diagnostic settings configured (Azure Monitor)
- When data disks are attached, the host cache is set to 'None'. But at the end of the script, user is asked if he wants to display host cache settings for data disks stored in JSON file to set manually the cache as it was.

 <br /> 

# Prerequisites

- User needs to have access to Get\create snapshots, disks, resource groups, additional resources necessary for creating a VM like, NICs, public IPs, VNETs, NSGs and to create a new VM
- User needs to have access to Azure cloud shell
- User needs to have access to his Azure Active Directory (for assigning proper permissions to AAD Application to have access to the keys and secrets from Key Vault).


# What it does

Deletes the original broken VM which is encrypted with Dual Pass (older version - with AAD) and recreate this VM from a previously exported configuration using as an OS disk, the disk that was fixed in the rescue environment created with script [**Create_Rescue_VM_from_DualPass_Encrypted_Vm**](https://github.com/gabriel-petre/ADE/tree/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm) or from the same OS disk

**Detailed steps:**

- Tests if the specified VM and disk exists
- Exports a JSON configuration file or uses an existing one
- Checks Vm Agent state
- For managed disks, creates a snapshot of the OS disk with name pattern like 'snap_$i_$OSDiskName'  where '$i' is incremental if a snapshot with the same name already exists. Note that snapshot name will be truncated if the number of characters is greater that "50"
- For managed disks, creates a disk from the snapshot for backup purposes  with name pattern like 'copy_$i_$OSDiskName'  where '$i' is incremental if a disk with the same name already exists. Note that disk name will be truncated if the number of characters is greater that "50". THe disk will be stored in the resource group of the specified disk.
- For managed disks, deletes the snapshot
- For unmanaged disks, creates a copy of the OS disk (blob) in the same storage account and container where the OS disk is stored.
- Checks if the specified disk is attached to a VM or not, offering possibility to detach the disk if it is attached to the rescue VM or continue if the specified disk is the current OS disk of VM that needs to be recreated 
- Checks if VM is encrypted with Dual Pass. If not, the script will end
- Gets encryption settings from JSON file
- For managing encryption keys in the key vault, user is offered to select an option from below to get the details of an Azure AD application and a secret that will be used in the process of authentication in Azure AD:
  - To specify the secret value of a secret that was already created in the AAD App that was found and will be used further in the encryption process
  - To specify the ID of an existing AAD Application and existing secret value from the same AAD Application that will used in the encryption process
  - To create a new secret in the AAD App user specifies and will used in the encryption process
  - If the options above are not feasible, user can create a new AAD Application and secret that will be used in the encryption process
- Based on the selected option script will proceed taking the proper actions to have in the end, an AAD application ID and a secret that will be used in the process of authentication in Azure AD
- For managing encryption keys and secrets in the key vault, the Azure AD application needs to have permission on the Key Vault, so user is offered to select an option from below to deal with permissions:
  - Permissions will be set automatically as long as your user has access to do this operation
  - User need to manually give permissions for the AAD Application on keys and secrets from Key vault and run again the script
  - User needs to confirm that permissions are already set
- Based on the selected option script will proceed taking the proper actions for the AAD Application to have proper permissions to  keys and secrets from Key vault or stop for the user to manually assign those permissions 
- Check if encryption settings gathered can successfully encrypt VM  
- Checks if the option of delete OS disk, data disks and NICs are set to be delete when VM is deleted
- Detaches data disks 
- Deletes VM
- Adds encryption settings gathered to the VM Configuration
- Recreates VM from VM configuration created based on the settings from found in JSON file and listed on Supported features\scenarios section
- Checks Vm Agent state
- Displays encryption settings gathered
- For Linux VMs:
  - Creates a backup of folder '/var/lib/azure_disk_encryption_config/' into path '/var/lib/azure_disk_encryption_backup_config/' 
  - Removes file '/var/lib/azure_disk_encryption_config/azure_crypt_params.ini' to resolve some issues
- Installs ADE extension with encryption settings gathered
- For Linux VMs: Creates an empty 'azure_crypt_params.ini' file into path '/var/lib/azure_disk_encryption_config/azure_crypt_params.ini' to avoid future issues
- Asks user if he wants to delete the backup disk that was created at the beginning of the script  
- Asks user if he wants to display host cache settings for data disks stored in JSON file, since when data disks are attached the host cache is set to 'None'

<br />

### Additional checks and actions: 

| <div style="width:400px">**Checks**</div> | <div align="left"><div style="width:400px" >**Actions**</div>|
|----------------------------------------------------------|:----------------------------------------------:|
| <div style="width:400">Before VM deletion check of Vm Agent state</div> | <div align="left"><div style="width:700px">If No -> Show warning message that it is highly recommended that the VM agent is in a 'Ready State', since for the encryption process (add ADE extension) to be successful (which happens after this Vm will be deleted and recreated) the VM agent needs to be in a 'Ready' state after Vm will be recreated. If VM agent needs is NOT in a 'Ready' state after Vm will be recreated, script will stop and encryption process (add ADE extension) needs to be manually resumed or run again this script once VM is in a 'Ready' state <br /> If Yes -> Continue</div>|
| <div style="width:400px">Checks if the specified disk is attached to a VM </div> | <div align="left"><div style="width:700px">If No -> Continue <br /> If Yes -> Ask user to detach the disk</div>|
| <div style="width:200x">If Vm is encrypted with Dual Pass</div> | <div align="left"><div style="width:700px">If No -> Stop script <br /> If Yes -> Continue</div>|
| <div style="width:200x">When creating a new AAD Application, check if another AAD App exists with the same name</div> | <div align="left"><div style="width:700px">If No -> Create a new AAD Application <br /> If Yes -> Request again to enter a different name</div>|
| <div style="width:800px">Check if user has the role 'Key Vault Administrator' for Azure role-based access control Key Vault Permission model</div> | <div align="left"><div style="width:700px">If no -> assign 'Key Vault Administrator' role to user </div>|
| <div style="width:800px">Check if encryption settings gathered can successfully encrypt VM </div> | <div align="left"><div style="width:700px">If No -> Asks user to resolve the errors and run again the script <br /> If Yes -> Continue </div>|
| <div style="width:800px">Check if the OS disk is set to be deleted when VM is deleted </div> | <div align="left"><div style="width:700px">If No -> Continue <br /> If Yes -> Disable this option </div>|
| <div style="width:800px">Check if the NICs are set to be deleted when VM is deleted </div> | <div align="left"><div style="width:700px">If No -> Continue <br /> If Yes -> Stop script </div>|
| <div style="width:800px">Check if the Data disks are set to be deleted when VM is deleted </div> | <div align="left"><div style="width:700px">Script is not checking this, but it is dettaching data disks before deleting VM to avoid deleting the data disks when VM is deleted  </div>|
| <div style="width:400">After VM was recreated check of Vm Agent state</div> | <div align="left"><div style="width:700px">Waiting 5 minutes for the VM agent to become ready or the script will stop after 5 minutes since encryption will not be able to start without the VM agent in a ready state</div>|
| <div style="width:400">Check if VM is encrypted with BEK or KEK</div> | <div align="left"><div style="width:700px">Encrypt VM based on the results</div>|
| <div style="width:400">Ask user of he wants to delete the backup disk that was create at the beginning </div> | <div align="left"><div style="width:700px">If No -> Stop script <br /> If Yes -> Delete Disk -> Stop script</div>|

Please check the diagram with the detailed steps: <br />
[![Image Link Text]
### Diagram
Please check the diagram with the detailed steps 
<br />*(click on the link to open the diagram in a new tab in full size)*
<br />
<br /> [Recreate DualPass VM from Disk - Diagram](https://raw.githubusercontent.com/gabriel-petre/ADE/main/Recreate_DualPass_VM_from_disk/Recreate_DualPass_VM_from_disk.jpg)
<br />

# Troubleshooting logs:

| <div style="width:550px">Logs in the Azure cloud shell drive</div> | <div align="left">Tool<div style="width:150px" ></div> | <div align="left">Description<div style="width:400px"> </div> |
|----------------------------------------------------------|:----------------------------------------------:|----------------------------------------------:|
| <div style="width:550px">$HOME/RecreateScript_Execution_log.txt</div> | <div align="left">Powershell script<div style="width:150px"></div> | <div align="left">Main execution log<div style="width:400px"> </div>|

<br />

# Important files:

| <div style="width:550px">Config file in the Azure cloud shell drive</div> | <div align="left">Tool<div style="width:150px" ></div> | <div align="left">Description<div style="width:400px"> </div> |
|----------------------------------------------------------|:----------------------------------------------:|----------------------------------------------:|
| <div style="width:550px">$HOME/VM_$VmName_Settings_$TimeNow.json</div> | <div align="left">Powershell script<div style="width:150px"></div> | <div align="left">Contains VM configuration which is exported in this JSON file from which Vm will be recreated <br/> $TimeNow -> stores the time in that moment and that time is added at the end of the name of the JSON file everytime the VM configuration is exported in another JSON file  <div style="width:400px"> </div>|

<br />

# Useful troubleshooting details

- The hostname was not changed and it will be the same. If the hostname is important, like VM was domain joined, manually rejoin VM to domain
  
<br />

  
# How to use the script

**Important:**<p style="color:red">**Please use a new page of Azure Cloud Shell before running the script, since Azure Cloud Shell has a timeout period of 20 minutes of inactivity.
<br />If Azure Cloud Shell times out the script is running, the script will stop at the time of the timeout.
<br />If the script is stopped until it finishes, environment might end up in an 'unknown state'.** </p >
<br />**If for some reason Azure Cloud shell still times out, manually delete all the resources created until that point, and run again the script.**

## 1. Download\Upload script to Azure cloud shell $HOME directory

### **Option 1** - Download the script from github repository to the Azure cloud shell drive:

- Open [**Script repository**](https://github.com/gabriel-petre/ADE/tree/main/Recreate_DualPass_VM_from_disk)
- Check what is the latest available version of the script
- Modify the command bellow to download the latest version of the script in to the $HOME directory of your Azure cloud shell session.
```PowerShell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gabriel-petre/ADE/main/Recreate_DualPass_VM_from_disk/Recreate_DualPass_VM_from_disk_1.0.ps1" -OutFile $home/Recreate_DualPass_VM_from_disk_1.0.ps1
```
- Open [**Azure Cloud Shell**](http://shell.azure.com/)
- Paste the command and enter to download the script in to the $HOME directory of your Azure cloud shell session.


### **Option 2** - Upload the script from your local machine to to the Azure cloud shell drive:

- Download the latest version of the script "Recreate_DualPass_VM_from_disk" from the [**repository**](https://github.com/gabriel-petre/ADE/tree/main/Recreate_DualPass_VM_from_disk)  
- Open [**Azure Cloud Shell**](http://shell.azure.com/)
- Click on the Upload\Download\Manage file share icon, click on upload and select from your local machine the script you previously downloaded

<br />

## 2. Run the script

- Open [**Azure Cloud Shell**](http://shell.azure.com/)
- From the left up corner section, select 'Powershell'
- See below examples on how to run the script:

<pre>
Recreate_DualPass_VM_from_disk_1.0.ps1 
    [-SubscriptionID] 
    [-VmName] 
    [-VMRgName]
    [-OSDiskName]
    [-OSDiskRg]                         <span style="color:green">#For VMs with Managed disks only </span>
    [-NewOSDiskStorageAccountName]      <span style="color:green">#For VMs with Unmanaged disks only </span>
    [-NewOSDiskContainer]               <span style="color:green">#For VMs with Unmanaged disks only </span>
</pre>

**Example of how to run the script for VMs with managed disks:**
```PowerShell
./Recreate_DualPass_VM_from_disk_1.0.ps1 -SubscriptionID "<Subscription ID>" -VmName "<Impacted VM Name>" -VMRgName "<Impacted VM resource group Name>" -OSDiskName "<Name of the disks that will be the OS disk>" -OSDiskRg "<Resource Group Name of the disks that will be the OS disk>"
```
*Note: Command above will Delete VM, recreate VM from the exported config JSON file and encrypt it again using Dual Pass method*

**Example of how to run the script for VMs with unmanaged disks:**
```PowerShell
./Recreate_DualPass_VM_from_disk_1.0.ps1 -SubscriptionID "<Subscription ID>" -VmName "<Impacted VM Name>" -VMRgName "<Impacted VM resource group Name>" -OSDiskName "<Name of the disks that will be the OS disk>" -NewOSDiskStorageAccountName "<Name of the storage account>" -NewOSDiskContainer "<Name of the container from the storage account>"
```
*Note: Command above will Delete VM, recreate VM from the exported config JSON file and encrypt it again using Dual Pass method*
 
| <div style="width:200px">**Mandatory parameters**</div> | <div align="left"><div style="width:400px" >Description</div>|
|----------------------------------------------------------|:----------------------------------------------:|
| <div style="width:130px">-SubscriptionID</div> | <div align="left"><div style="width:700px">Subscription ID where VM resides</div>|
| <div style="width:130px">-VmName</div> |<div align="left"> <div style="width:700px">The name of the Virtual machine that is experiencing issues and you want to delete, then recreate and then encrypt again with Dual Pass</div>|
| <div style="width:130px">-VMRgName</div> | <div align="left"><div style="width:700px">The resource group name of the same Virtual machine </div>
| <div style="width:130px">-OSDiskName</div> |<div align="left"> <div style="width:700px">The name of the disks that will be the OS disk</div>|
| <div style="width:130px">-OSDiskRg</div> |<div align="left"> <div style="width:700px">The name of the resource Group of the disks that will be the OS disk <br /><span style="color:green">#For VMs with Managed disks only </span></div>|
| <div style="width:250px">-NewOSDiskStorageAccountName</div> |<div align="left"> <div style="width:700px">The name of the storage account where the fixed disk resides and that will be the OS disk <br /><span style="color:green">#For VMs with Unmanaged disks only </span></div>|
| <div style="width:250px">-NewOSDiskContainer</div> |<div align="left"> <div style="width:700px">The name of the container from the storage account where the fixed disk resides and that will be the OS disk <br /><span style="color:green">#For VMs with Unmanaged disks only </span></div>|
  
<br />


