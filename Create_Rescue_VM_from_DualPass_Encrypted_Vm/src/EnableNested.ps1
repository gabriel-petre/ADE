Start-Transcript -Path "c:\Unlock Disk\EnableNested-log.txt" -Append | Out-Null
get-date
# Put the BEK volume disk offline
$BEKVolumeNumber = (get-disk | ?{($_.operationalstatus -eq "Online") -and ($_.IsSystem -eq $false) -and ($_.size -like "503*") }).Number
Set-Disk -number $BEKVolumeNumber -IsOffline $True
 #Put encrypted disk offline
$NumberOfEncryptedDisk = (get-disk | ?{($_.number -gt "0") -and ($_.size -gt "128849018880")}).Number
Set-Disk -Number $NumberOfEncryptedDisk -IsOffline $True 
#Create VM in Hyper-V
$HypervVMName = "RescueVM"
New-VM -Name $HypervVMName -Generation 1 -MemoryStartupBytes 4GB -NoVHD
Set-VM -name $HypervVMName -ProcessorCount 2
#Removing DVD drive
Remove-VMDvdDrive -VMName $HypervVMName -ControllerNumber 1 -ControllerLocation 0
# add disks to Hyper-V VM
$BEKVolumeNumber = (get-disk | ?{($_.IsSystem -eq $false) -and ($_.size -like "503*") }).Number
Get-Disk $NumberOfEncryptedDisk | Add-VMHardDiskDrive -VMName $HypervVMName -ControllerType IDE -ControllerNumber 0
Get-Disk $BEKVolumeNumber | Add-VMHardDiskDrive -VMName $HypervVMName -ControllerType IDE -ControllerNumber 1
New-VMSwitch -Name "Nested-VMs" -SwitchType Internal
New-NetIPAddress -IPAddress 192.168.0.1 -PrefixLength 24 -InterfaceAlias "vEthernet (Nested-VMs)"
Add-DhcpServerV4Scope -Name "Nested-VMs" -StartRange 192.168.0.2 -EndRange 192.168.0.254 -SubnetMask 255.255.255.0
Set-DhcpServerV4OptionValue -DnsServer 8.8.8.8 -Router 192.168.0.1
New-NetNat -Name Nat_VM -InternalIPInterfaceAddressPrefix 192.168.0.0/24
Get-VM | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "Nested-VMs"
#create .bat script stored in startup folder for all users, which will start_Hyper-V_Manager when a user RDPs

$StartupFolderAllUsers = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$StartupUnlockDiskBatScriptPath = New-Item "$StartupFolderAllUsers\Start_Hyper-V_Manager.bat"
Add-Content "$StartupUnlockDiskBatScriptPath" 'start Virtmgmt.msc'
Stop-Transcript | Out-Null
