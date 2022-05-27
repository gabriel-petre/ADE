# What is this automated process

This automated process is actually a powershell script
<br /><p style="color:red">The script was designed to create a rescue environment only for VMs which are encrypted with Dual Pass (older version - with AAD) BEK and KEK</p>

<br />

# Why this automated process was created

- There are times when you need to troubleshoot a VM in scenarios like: Os no boot, connectivity issues or others.
- There are other tools that can help you in this process for the connectivity scenarios like Run command, serial console, remote powershell, psexec, but often this tools cannot be used for different reasons
- In a no boot scenario, you are limited in troubleshooting and the most common path is to create a rescue environment (create a rescue VM, attach a copy of the broken OS disk as a data disk to this VM and maybe install Hyper-V role and create a VM inside Hyper-V)

- For non-encrypted VMs, you can easily create a rescue environment either manually or using Az VM repair  
<br /> What about when that VM is encrypted?
<br />
- When that VM is encrypted with Single Pass (newest version - without AAD), to create a rescue environment you can use either the manual process or Az VM repair  which supports creating a rescue environment for single pass encrypted VMs
- When that VM is encrypted with Dual Pass (older version - with AAD), the only method of creating a rescue environment is to do it manually since Az Vm repair doesn't support dual pass encrypted VMs

The answer to why this process was created is, to automate the process of creating a rescue VM and if necessary install Hyper-V and configure VM inside Hyper-V for broken VMs that are encrypted with Dual Pass (older version - with AAD)

<br />

# Advantages 

- This is an automated process for creating all necessary resources for starting the troubleshooting process for VMs which are encrypted with Dual Pass (older version - with AAD) 
- This powershell script was designed to be used from Azure cloud shell, to eliminate the need of powershell prerequisites needed in the manual process and which caused delays or additional issues due to the diversity of environments in terms of Powershell version, Os version, user permissions, internet connectivity etc.
- The duration for this process using this script is between 4 minutes and 15 minutes (depending on the option selected), which far more less than the manual process which can take hours or even days depending on the complexity of scenarios, environment variables, customer limitations, level of expertise
- Reduced risk of human errors in gathering and using encryption settings
- Available backups in case of the worst scenarios
- No internet access is required for the Rescue VM which is useful for users with restricted environments
- The use of the script, has no limitations that were found regarding the operating system versions (Window or Linux) **supported in Azure**
- Possibility and compatibility to chose the most common and newest operating system version, Window or Linux, to create the rescue environment 
- Insignificant number of initial input data needed to run this script
- Available execution\troubleshooting logs that can be used to investigate\improve the runtime of this script
- Additional checks during this process to reduce or prevent the risk of a script failure due to the variety of environments
- Additional explanatory details offered during the process, which helps the user to learn also theoretical aspects along the way
- Error handling for the most common errors in terms of auto-resolving or guidance for the manual process of resolving the issue
- Offers the possibility of using the script multiple times if the troubleshooting scenario requires this

<br />

# Scenarios where ca be used (but not limited to them)

VM's operating system is not booting properly
VM has connectivity issues and other available tools cannot be used or this process like:
- User cannot connect using RDP\SSH
- Network card issues (Vm isolated)
- Public IP issues

<br />

# Supported features\scenarios

- VM encrypted with Pass (older version - with AAD) BEK and KEK
- VMs with Managed and Unmanaged disks 
- VMs with Windows\Linux existing supported operating systems
- Add up to 5 name\value pairs as tags for the rescue VM 
- Existing resource groups
- Existing Storage containers (for unmanaged disks)
- Restricted environments, since no internet access is required for the Rescue VM to be created, configured and for the data disk to be unlocked. All the necessary resources are downloaded or created directly in azure drive and then pushed to the rescue VM using Invoke-AzVMRunCommand
    
 <br /> 

# Limitations

- The script was designed to be used **only** on VMs which are encrypted with Dual Pass (older version - with AAD)
- The script was designed to be used **only** in [**Azure Cloud Shell**](http://shell.azure.com/)>

  
<br />

# Prerequisites

- User needs to have access to Get\create snapshots, disks, resource groups, additional resources necessary for creating a VM like, NICs, public IPs, VNETs, NSGs and to create a new VM
- User needs to have access to Azure cloud shell
- User needs to have access to his Azure Active Directory (for assigning proper permissions to AAD Application to have access (like list and create) to the keys and secrets from Key Vault ). Even though this script doesn't really need this kind of access, it will be needed in the recreate process of this VM once the issue was fixed since swapping disks are not supported for Dual Pass (older version - with AAD) encrypted disks.

<br />

# What it does

It creates a rescue environment to be able to troubleshoot the actual issue of impacted VM

**Detailed steps:**
- Creates a copy of the OS disk of impacted VM
- Removes encryption settings from the disk created to be able to attach it to rescue VM
- Outputs encryption settings as a reference
- Creates a rescue VM with the option of choosing the operating system version depending if it is Windows or Linux
- Copies encryption settings to the rescue VM  to that Azure platform to attach the 'BEK Volume' which contains the unlock key.
- Attaches the copy for the OS disk of impacted VM as a data disk to the Rescue VM
- Creates a script that will stored in cloud drive that will be sent using Invoke-AzVMRunCommand to the rescue VM and will unlock the disk
- If used, the -enablenested parameter creates a script that will stored in cloud drive that will be sent using Invoke-AzVMRunCommand to the rescue VM and will install Hyper-V role and reboot VM.
- If used, the -enablenested parameter creates another script that will stored in cloud drive that will be sent using Invoke-AzVMRunCommand to the rescue VM and will configure\create VM inside Hyper-V from the data disk attached, after putting the data disk and BEK Volume offline
- Creates an "Unlock Disk" powershell script on the desktop for different troubleshooting scenarios
- Deletes all the additional scripts used by the main script from the cloud drive

<br />

### Additional checks and actions: 

| <div style="width:200px">**Checks**</div>                                                                                                    |                                    <div align="left"><div style="width:400px" >**Actions**</div>                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------: |
| <div style="width:130px">If VM exists</div>                                                                                                  |                                <div align="left"><div style="width:700px">If No -> Stop Script</div>                                 |
| <div style="width:200x">What is the Key Vault Permission model</div>                                                                         |                                      <div align="left"><div style="width:700px">No Action</div>                                      |
| <div style="width:800px">If user has the role 'Key Vault Administrator' for Azure role-based access control Key Vault Permission model</div> |               <div align="left"><div style="width:700px">If no -> assign 'Key Vault Administrator' role to user </div>               |
| <div style="width:130px">No check available</div>                                                                                            |      <div align="left"><div style="width:700px">Adds an Access Policy to give permissions on the keys and secret to user</div>       |
| <div style="width:200x">If role assignment or access policy creation fails due to user permissions issue </div>                              | <div align="left"><div style="width:700px">Set permission based on entered ObjectId if user has the 'ObjectId' of his AAD user</div> |
| <div style="width:200x">If Vm is encrypted with Dual Pass</div>                                                                              |                                <div align="left"><div style="width:700px">If No -> stop script</div>                                 |
| <div style="width:200x">If Vm is encrypted with BEK or KEK</div>                                                                             |                                      <div align="left"><div style="width:700px">No Action</div>                                      |
| <div style="width:200x">If Resource group exists</div>                                                                                       |     <div align="left"><div style="width:700px">If Yes -> Use existing resource group <br /> If No -> Create resource group/div>      |



### Diagram
Please check the diagram with the detailed steps 
<br />*(click on the link to open the diagram in a new tab in full size)*
<br />
<br /> [Create DualPass VM from Disk - Diagram](https://raw.githubusercontent.com/gabriel-petre/ADE/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm/Create_Rescue_VM_from_DualPass_Encrypted_Vm.jpg)

# Restore VM 

- As mentioned, this script creates a rescue environment to be able to troubleshoot the actual issue of impacted VM. 
- Once the issue was resolved, to be able to bring online the fixed VM from the rescue environment back in Azure, since "swap disk" feature is not supported\working on dual pass encrypted VMs, another script was created which will recreate the original VM from the fixed disks, by deleting original VM and recreate it back and then encrypt it again with dual pass.
- The script which will recreate the original VM from the fixed disks can be found in the (restore process) [**repository**](https://github.com/gabriel-petre/ADE/blob/main/Recreate_DualPass_VM_from_disk/Recreate_DualPass_VM_from_disk_1.0.ps1). 

<br />

# Additional scripts used by the main script:

| <div style="width:550px">Additional Scripts added\created in Azure cloud shell drive and sent to Rescue VM</div> | <div align="left">Operating System<div style="width:150px" ></div> |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      <div align="left">Description<div style="width:300px" ></div> |
| ---------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| <div style="width:550px">$HOME/Unlock-Disk</div>                                                                 |      <div align="left">Windows<div style="width:150px"></div>      |  <div align="left"> - Unlocks the encrypted data disks on the rescue <br /> - Sets ExecutionPolicy to unrestricted <br />  - Disables Server Manager from startup <br /> - Creates on the rescue VM script "C:\Users\Public\Desktop\Unlock disk.ps1" <br />  - Creates on the rescue VM script "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Unlock disk.ps1" <br /> - Creates in the Rescue VM script C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\unlock_disk.bat <br /> - Creates in the Rescue VM log file c:\Unlock Disk\Unlock-Script-log.txt <br /> **Script will be deleted once the main script finishes**<div style="width:300px"></div> |
| <div style="width:550px">$HOME/Install-Hyper-V-Role</div>                                                        |      <div align="left">Windows<div style="width:150px"></div>      |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       <div align="left"> Instals Hyper-V and DHCP Windows Features <br /> **Script will be deleted once the main script finishes** <div style="width:300px"></div> |
| <div style="width:550px">$HOME/EnableNested</div>                                                                |      <div align="left">Windows<div style="width:150px"></div>      | <div align="left"> - Creates in the Rescue VM log file c:\Unlock Disk\EnableNested-log.txt <br /> - Puts encrypted disk and BEK volume offline <br /> - Removes DVD drive <br /> - Creates a virtual switch <br /> - Creates a DHCP scope that will be used to automatically assign IP to the nested VMs <br /> - Creates NAT to allow internet access <br /> - Connects the virtual network of VM in Hyper-V to virtual switch <br /> - Creates script C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Start_Hyper-V_Manager.bat to open Hyper-V Manager when logs in <br /> **Script will be deleted once the main script finishes**<div style="width:300px"></div> |
| <div style="width:550px">$HOME/linux-mount-encrypted-disk.sh</div>                                               |       <div align="left">Linux<div style="width:150px"></div>       |                                                                                                                                                                               <div align="left"> - Creates in the Rescue VM log file /var/log/vmrepair/vmrepair.log <br /> - Install required packages (cryptsetup, lvm2)<br /> - Mounts BEK Volume <br /> - Creates directories (mount points) {investigateboot,investigateroot} <br /> - Rename local VG (LVM) to "rescuevg"  <br /> - Mounts partitions <br /> - Mounts Boot <br /> - Unlocks Root <br /> - Verifies root unlock <br /> **Script will be deleted once the main script finishes**<div style="width:300px"></div> |

<br />

| <div align="left"><div style="width:550px" >Useful scripts in Rescue VM</div>                                                 | <div align="left"><div style="width:150px" >Operating System</div> |                                                                                                                                               <div align="left">Description<div style="width:300px" ></div> |
| ----------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------: | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| <div align="left"><div style="width:550px">C:\Unlock Disk\Unlock disk.ps1</div>                                               |      <div align="left"><div style="width:150px">Windows</div>      |                                                                                                                                   <div align="left">Unlocks encrypted disk <div style="width:300px"> </div> |
| <div align="left"><div style="width:550px">C:\Users\Public\Desktop\Unlock disk.ps1</div>                                      |     <div align="left"> <div style="width:150px">Windows</div>      | <div align="left"> Checks if the BEK volume is offline and sets it online <br /> Checks if encrypted disk is offline and sets it online <br /> Unlocks encrypted data disk<div style="width:300px">  </div> |
| <div align="left"><div style="width:550px">C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\unlock_disk.bat</div> |      <div align="left"><div style="width:150px">Windows</div>      |                                                                                         <div align="left"> Runs script  'C:\Unlock Disk\Unlock disk.ps1' when user logs in<div style="width:300px">  </div> |

<br />

# Troubleshooting logs:

| <div style="width:550px">Logs in the Azure cloud shell drive</div>          |       <div align="left">Tool<div style="width:150px" ></div>       |        <div align="left">Description<div style="width:400px"> </div> |
| --------------------------------------------------------------------------- | :----------------------------------------------------------------: | -------------------------------------------------------------------: |
| <div style="width:550px">$HOME/CreateRescueVMScript_Execution_log.txt</div> | <div align="left">Powershell script<div style="width:150px"></div> | <div align="left">Main execution log<div style="width:400px"> </div> |

<br />

| <div align="left"><div style="width:550px" >Logs in the Rescue VM</div>                      | <div align="left"><div style="width:150px">**Operating System**</div> |                                                     <div align="left"><div style="width:400px">Description</div> |
| -------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------: | ---------------------------------------------------------------------------------------------------------------: |
| <div align="left"><div style="width:550px">c:\Unlock Disk\Unlock-Disk-log.txt</div>          |       <div align="left"><div style="width:150px">Windows</div>        |                    <div align="left"><div style="width:400px" > Execution log for script $HOME/Unlock-Disk</div> |
| <div align="left"><div style="width:550px">c:\Unlock Disk\EnableNested-log.txt</div>         |       <div align="left"><div style="width:150px">Windows</div>        |                  <div align="left"><div style="width:400px" > Execution log for script $HOME/EnableNested </div> |
| <div align="left"><div style="width:550px">c:\Unlock Disk\Install-Hyper-V-Role-log.txt</div> |       <div align="left"><div style="width:150px">Windows</div>        |           <div align="left"><div style="width:400px" > Execution log for script $HOME/Install-Hyper-V-Role</div> |
| <div align="left"><div style="width:550px">/var/log/vmrepair/vmrepair.log</div>              |        <div align="left"><div style="width:150px">Linux</div>         | <div align="left"><div style="width:400px" > Execution log for script $HOME/linux-mount-encrypted-disk.sh<</div> |



<br />

# Useful troubleshooting details

- The name of the copy of the OS disk that will be created and attached to the Rescue VM follow this pattern: 'fixed_$i_OriginalOsDiskName' where '$i' is incremental if a disk with the same name already exists. Note that disk name will be truncated if the number of characters is greater that "50"
- For Windows Rescue VMs, once a user RDP to that VM, the Hyper-V manager will be started automatically
- If the rescue VM is rebooted, data disk should be automatically unlocked after 1-2 minutes
- If for some reason disk doesn't unlock automatically or you need to unlock manually the disks during troubleshooting, user can unlock encrypted data disk using 'Unlock disk.ps1' script from desktop
- VM created inside Hyper-V is configured to allow outbound connectivity to internet
- VM created inside Hyper-V is configured to be accessible from the Rescue VM (via RDP, ping, etc..)
- For Linux VM, this is how the output of "lsblk" looks like on the rescue VMs if the broken VM doesn't have LVM and if it does:

<pre>
                           With LVM:                                                                                          Without LVM:

NAME                MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT                                                       NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                   8:0    0   64G  0 disk                                                                   sda       8:0    0   30G  0 disk 
├─sda1                8:1    0  500M  0 part  /boot                                                            ├─sda1    8:1    0 29.9G  0 part /
├─sda2                8:2    0   63G  0 part                                                                   ├─sda14   8:14   0    4M  0 part 
│ ├─rescuevg-tmplv  253:0    0    2G  0 lvm   /tmp                                                             └─sda15   8:15   0  106M  0 part /boot/efi
│ ├─rescuevg-usrlv  253:1    0   10G  0 lvm   /usr                                                             sdb       8:16   0  128G  0 disk 
│ ├─rescuevg-homelv 253:2    0    1G  0 lvm   /home                                                            ├─sdb1    8:17   0 29.7G  0 part 
│ ├─rescuevg-varlv  253:3    0    8G  0 lvm   /var                                                             ├─sdb2    8:18   0  256M  0 part /investigateboot
│ └─rescuevg-rootlv 253:4    0    2G  0 lvm   /                                                                ├─sdb14   8:30   0    4M  0 part 
├─sda14               8:14   0    4M  0 part                                                                   └─sdb15   8:31   0  106M  0 part /tmp/dev/sdb15
└─sda15               8:15   0  495M  0 part  /boot/efi                                                        sdc       8:32   0   16G  0 disk 
sdb                   8:16   0   16G  0 disk                                                                   └─sdc1    8:33   0   16G  0 part /mnt
└─sdb1                8:17   0   16G  0 part  /mnt                                                             sdd       8:48   0   48M  0 disk 
sdc                   8:32   0  128G  0 disk                                                                   └─sdd1    8:49   0   46M  0 part /mnt/azure_bek_disk
├─sdc1                8:33   0  500M  0 part  /tmp/dev/sdc1                                                    sr0      11:0    1 1024M  0 rom 
├─sdc2                8:34   0  500M  0 part  /investigateroot/boot
├─sdc3                8:35   0    2M  0 part  
└─sdc4                8:36   0   63G  0 part  
  └─osencrypt       253:5    0   63G  0 crypt 
    ├─rootvg-tmplv  253:6    0    2G  0 lvm   /investigateroot/tmp
    ├─rootvg-usrlv  253:7    0   10G  0 lvm   /investigateroot/usr
    ├─rootvg-optlv  253:8    0    2G  0 lvm   /investigateroot/opt
    ├─rootvg-homelv 253:9    0    1G  0 lvm   /investigateroot/home
    ├─rootvg-varlv  253:10   0    8G  0 lvm   /investigateroot/var
    └─rootvg-rootlv 253:11   0    2G  0 lvm   /investigateroot
sdd                   8:48   0   48M  0 disk  
└─sdd1                8:49   0   46M  0 part  /mnt/azure_bek_disk
sr0                  11:0    1 1024M  0 rom                                                             
</pre>

 <br /> 

# How to use the script

**Important:**<p style="color:red">**Please use a new page of Azure Cloud Shell before running the script, since Azure Cloud Shell has a timeout period of 20 minutes of inactivity.
<br />If Azure Cloud Shell times out the script is running, the script will stop at the time of the timeout.
<br />If the script is stopped until it finishes, environment might end up in an 'unknown state'.** </p >
<br />**If for some reason Azure Cloud shell still times out, manually delete all the resources created until that point, and run again the script.**

## 1. Download\Upload script to Azure cloud shell $HOME directory

### **Option 1** - Download the script from github repository to the Azure cloud shell drive:

- Open [**Script repository**](https://github.com/gabriel-petre/ADE/tree/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm)
- Check what is the latest available version of the script
- Modify the command bellow to download the latest version of the script in to the $HOME directory of your Azure cloud shell session.
```PowerShell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gabriel-petre/ADE/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm/Create_Rescue_VM_from_DualPass_Encrypted_Vm_1.0.ps1" -OutFile $home/Create_Rescue_VM_from_DualPass_Encrypted_Vm_1.0.ps1 
```
- Open [**Azure Cloud Shell**](http://shell.azure.com/)
- Paste the command and enter to download the script in to the $HOME directory of your Azure cloud shell session.


### **Option 2** - Upload the script from your local machine to to the Azure cloud shell drive:

- Download the latest version of the script "Create_Rescue_VM_from_DualPass_Encrypted_Vm" from the [**repository**](https://github.com/gabriel-petre/ADE/tree/main/Create_Rescue_VM_from_DualPass_Encrypted_Vm) 
- Open [**Azure Cloud Shell**](http://shell.azure.com/)
- Click on the Upload\Download\Manage file share icon, click on upload and select from your local machine the script you previously downloaded

<br />

## 2. Run the script

- Open <a href="http://shell.azure.com/" target="_blank">Azure Cloud Shell</a> 
- From the left up corner section, select 'Powershell'
- See below examples on how to run the script:

<pre>
Create_Rescue_VM_from_DualPass_Encrypted_Vm_1.0.ps1 
    [-SubscriptionID] 
    [-VmName] 
    [-VMRgName]
    [-RescueVmName]
    [-RescueVmRg]
    [-CopyDiskName]
    [-RescueVmUserName]
    [-RescueVmPassword]
    [-associatepublicip]
    [-enablenested]         <span style="color:green">#For Windows VMs only </span>
    [-TagName1]
    [-TagValue1]
    [-TagName2]
    [-TagValue2]
    [-TagName3]
    [-TagValue3]
    [-TagName4]
    [-TagValue4]
    [-TagName5]
    [-TagValue5]
</pre>

**Example 1 of how to run the script (Managed and Unmanaged disks):**
```PowerShell
./Create_Rescue_VM_from_DualPass_Encrypted_Vm_1.0.ps1 -SubscriptionID "<Subscription ID>" -VmName "<Impacted VM Name>" -VMRgName "<Impacted VM resource group Name>" -RescueVmName "<Rescue VM Name>" -RescueVmRg "<Impacted VM resource group Name>" -CopyDiskName "<Name for the copy of the OS disk>" -RescueVmUserName "<User Name>" -RescueVmPassword "<Password>"
```
*Note: Command above will create a Rescue VM without a public IP, attach as a data disk a copy of the OS disk of the impacted VM and unlock that data disk*
 
 **Example 2 of how to run the script (Managed and Unmanaged disks):**
 ```PowerShell
./Create_Rescue_VM_from_DualPass_Encrypted_Vm_1.0.ps1 -SubscriptionID "<Subscription ID>" -VmName "<Impacted VM Name>" -VMRgName "<Impacted VM resource group Name>" -RescueVmName "<Rescue VM Name>" -RescueVmRg "<Impacted VM resource group Name>" -CopyDiskName "<Name for the copy of the OS disk>" -RescueVmUserName "<User Name>" -RescueVmPassword "<Password>" -associatepublicip -enablenested
 ```
Note: Command above will create a Rescue VM with a public IP, install Hyper-V role, sets the data disk and BEK volume offline and configure\create a Vm inside Hyper-V from the data disks attached, which is a copy of the OS disk of the impacted VM. Once Hyper-V VM will be started, the OS will be able to unlock the data disk since BEK volume is also attached to that VM

 **Example 3 of how to run the script (Managed and Unmanaged disks):**
 ```PowerShell
./Create_Rescue_VM_from_DualPass_Encrypted_Vm_1.0.ps1 -SubscriptionID "<Subscription ID>" -VmName "<Impacted VM Name>" -VMRgName "<Impacted VM resource group Name>" -RescueVmName "<Rescue VM Name>" -RescueVmRg "<Impacted VM resource group Name>" -CopyDiskName "<Name for the copy of the OS disk>" -RescueVmUserName "<User Name>" -RescueVmPassword "<Password>" -associatepublicip -enablenested -TagName1 "<TagName1>" -TagValue1 "<TagValue1>" -TagName2 "<TagName2>" -TagValue2 "<TagValue2>" -TagName3 "<TagName3>" -TagValue3 "<TagValue3>" -TagName4 "<TagName4>" -TagValue4 "<TagValue4>" -TagName5 "<TagName5>" -TagValue5 "<TagValue5>"
 ```
Note: Command above will create a Rescue VM with a public IP and add 5 name\value pairs as TAGs , install Hyper-V role, sets the data disk and BEK volume offline and configure\create a Vm inside Hyper-V from the data disks attached, which is a copy of the OS disk of the impacted VM. Once Hyper-V VM will be started, the OS will be able to unlock the data disk since BEK volume is also attached to that VM


<br />

| <div style="width:200px">**Mandatory parameters**</div> |                                                   <div align="left"><div style="width:400px" >Description</div>                                                    |
| ------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| <div style="width:130px">-SubscriptionID</div>          |                                         <div align="left"><div style="width:700px">Subscription ID where VM resides</div>                                          |
| <div style="width:130px">-VmName</div>                  |                           <div align="left"> <div style="width:700px">The name of the Virtual machine that is experiencing issues</div>                            |
| <div style="width:130px">-VMRgName</div>                |                    <div align="left"><div style="width:700px">The resource group name of the Virtual machine that is experiencing issues</div>                     |
| <div style="width:130px">-RescueVmName</div>            |                           <div align="left"> <div style="width:700px">The name of the Rescue Virtual machine that will be created</div>                            |
| <div style="width:130px">-RescueVmRg</div>              |                    <div align="left"> <div style="width:700px">The resource group name of the Rescue Virtual machine that will be created</div>                    |
| <div style="width:130px">-CopyDiskName</div>            | <div align="left"> <div style="width:700px">The name for the copy of the OS disk that will be created, attached to the Rescue VM as a data disk and unlocked</div> |
| <div style="width:140px">-RescueVmUserName</div>        |                 <div align="left"> <div style="width:700px">The username used for accessing the Rescue Virtual machine that will be created</div>                  |
| <div style="width:130px">-RescueVmPassword</div>        |         <div align="left"> <div style="width:700px">The password for the username used for accessing the Rescue Virtual machine that will be created</div>         |

<br />

| <div style="width:200px">**Optional parameters**</div> |                                                                                                                                                                                                 <div align="left"><div style="width:400px" >Description</div>                                                                                                                                                                                                 |
| ------------------------------------------------------ | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| <div style="width:130px">-associatepublicip</div>      |                                                                                                                                                                      <div align="left"><div style="width:700px">Add a public IP to the Rescue Virtual machine that will be created</div>                                                                                                                                                                      |
| <div style="width:100px">-enablenested</div>           | <div align="left"> <div style="width:700px">Install Hyper-V role, sets the data disk and BEK volume offline and configure\create a Vm inside Hyper-V from the data disks attached, which is a copy of the OS disk of the impacted VM. <br />Once Hyper-V VM will be started, the OS will be able to unlock the data disk since BEK volume is also attached to that VM <span style="color:red"><br />**To be used only for Windows impacted VMs**</span></div> |
| <div style="width:100px">-TagName1</div>           | <div align="left"> <div style="width:700px">First tag Name to be added to the Rescue VM </div>|
| <div style="width:100px">-TagValue1</div>           | <div align="left"> <div style="width:700px"> First tag Value to be added to the Rescue VM </div>|
| <div style="width:100px">-TagName2</div>           | <div align="left"> <div style="width:700px">Second tag Name to be added to the Rescue VM </div>|
| <div style="width:100px">-TagValue2</div>           | <div align="left"> <div style="width:700px"> Second tag Value to be added to the Rescue VM </div>|
| <div style="width:100px">-TagName3</div>           | <div align="left"> <div style="width:700px">Third tag Name to be added to the Rescue VM </div>|
| <div style="width:100px">-TagValue3</div>           | <div align="left"> <div style="width:700px"> Third tag Value to be added to the Rescue VM </div>|
| <div style="width:100px">-TagName4</div>           | <div align="left"> <div style="width:700px">Fourth tag Name to be added to the Rescue VM </div>|
| <div style="width:100px">-TagValue4</div>           | <div align="left"> <div style="width:700px"> Fourth tag Value to be added to the Rescue VM </div>|
| <div style="width:100px">-TagName5</div>           | <div align="left"> <div style="width:700px"> The fifth tag Name to be added to the Rescue VM </div>|
| <div style="width:100px">-TagValue5</div>           | <div align="left"> <div style="width:700px"> The fifth tag Value to be added to the Rescue VM </div>|
<br />

