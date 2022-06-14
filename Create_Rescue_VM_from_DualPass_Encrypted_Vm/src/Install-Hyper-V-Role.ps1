Start-Transcript -Path "c:\Unlock Disk\Install-Hyper-V-Role-log.txt" -Append | Out-Null
Install-WindowsFeature -Name Hyper-V,DHCP -ComputerName localhost -IncludeManagementTools
Stop-Transcript | Out-Null
