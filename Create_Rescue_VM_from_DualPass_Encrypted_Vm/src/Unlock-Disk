Start-Transcript -Path "c:\Unlock Disk\Unlock-Script-log.txt" -Append | Out-Null
get-date
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -ExecutionPolicy unrestricted -Scope LocalMachine -force
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask >> $path
$DriveToUnlock= (Get-BitLockerVolume | ?{$_.KeyProtector -ne $null}).mountpoint
$BekVolumeDriveLetter = (Get-Volume -FileSystemLabel "Bek Volume").DriveLetter
$BekPath = $BekVolumeDriveLetter + ":\*"
$BekKeyName = (Get-ChildItem -Path $BekPath -Force -Include *.bek).Name
$BekPath = $BekVolumeDriveLetter + ":\" + $BekKeyName
manage-bde -unlock $DriveToUnlock -recoveryKey "$BekPath"
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask 
$DesktopUnlockScript = "C:\Users\Public\Desktop\Unlock disk.ps1"
$DesktopUnlockScripttPath = New-Item "C:\Users\Public\Desktop\Unlock disk.ps1"
Add-Content "$DesktopUnlockScripttPath" '#check if the BEK disk is offline and put it online'
Add-Content "$DesktopUnlockScripttPath" '$BEKVolumeNumber = (get-disk | ?{($_.operationalstatus -eq "Offline") -and ($_.IsSystem -eq $false ) -and ($_.size -like "503*") }).Number'
Add-Content "$DesktopUnlockScripttPath" 'If ($BEKVolumeNumber -ne $Null)'
Add-Content "$DesktopUnlockScripttPath" '{ $error.clear()'
Add-Content "$DesktopUnlockScripttPath" ' # try to bring the disk online. If Vm inside Hyper-V is running command will end with error and write-host to stop VM first '
Add-Content "$DesktopUnlockScripttPath" 'try {'
Add-Content "$DesktopUnlockScripttPath" 'Set-Disk -number $BEKVolumeNumber -IsOffline $False -ErrorAction SilentlyContinue'
Add-Content "$DesktopUnlockScripttPath" 'Write-Host "Setting Bek Volume as online..."}'
Add-Content "$DesktopUnlockScripttPath" 'catch {}'
Add-Content "$DesktopUnlockScripttPath" 'if ($error)'
Add-Content "$DesktopUnlockScripttPath" '{Write-host "Vm inside Hyper-V is running and it is using Bek Volume. Disk cannot be set as online. Stop Vm inside Hyper-V and run again the script" -ForegroundColor red'
Add-Content "$DesktopUnlockScripttPath" 'Write-Host "Script will exit in 30 seconds"'
Add-Content "$DesktopUnlockScripttPath" 'Start-Sleep 30'
Add-Content "$DesktopUnlockScripttPath" 'exit'
Add-Content "$DesktopUnlockScripttPath" '}'
Add-Content "$DesktopUnlockScripttPath" 'if (!$error)'
Add-Content "$DesktopUnlockScripttPath" '{Write-host "Bek Volume is online" -ForegroundColor green}'
Add-Content "$DesktopUnlockScripttPath" '}'
Add-Content "$DesktopUnlockScripttPath" '#check if the encrypted disk is offline and put it online '
Add-Content "$DesktopUnlockScripttPath" '$NumberOfEncryptedDisk = (get-disk | ?{($_.number -gt "0") -and ($_.size -gt "128849018880")}).Number'
Add-Content "$DesktopUnlockScripttPath" 'If ($NumberOfEncryptedDisk -ne $Null)'
Add-Content "$DesktopUnlockScripttPath" '{'
Add-Content "$DesktopUnlockScripttPath" '$error.clear()'
Add-Content "$DesktopUnlockScripttPath" '# try to bring the disk online. If Vm inside Hyper-V is running command will end with error and write-host to stop VM first'
Add-Content "$DesktopUnlockScripttPath" 'try {Set-Disk -number $NumberOfEncryptedDisk -IsOffline $False -ErrorAction SilentlyContinue'
Add-Content "$DesktopUnlockScripttPath" 'Write-Host "Setting Encrypted disk as online..."'
Add-Content "$DesktopUnlockScripttPath" '}'
Add-Content "$DesktopUnlockScripttPath" 'catch {}'
Add-Content "$DesktopUnlockScripttPath" 'if ($error)'
Add-Content "$DesktopUnlockScripttPath" '{Write-host "Vm inside Hyper-V is running and it is using the Encrypted disk. Disk cannot be set as online. Stop Vm inside Hyper-V and run again the script" -ForegroundColor red'
Add-Content "$DesktopUnlockScripttPath" 'Write-Host "Script will exit in 30 seconds"'
Add-Content "$DesktopUnlockScripttPath" 'Start-Sleep 30'
Add-Content "$DesktopUnlockScripttPath" 'exit'
Add-Content "$DesktopUnlockScripttPath" '}'
Add-Content "$DesktopUnlockScripttPath" 'if (!$error)'
Add-Content "$DesktopUnlockScripttPath" '{Write-host "Encrypted disk is online" -ForegroundColor green}'
Add-Content "$DesktopUnlockScripttPath" '}'
Add-Content "$DesktopUnlockScripttPath" 'Write-Host "Unlocking disk..."'
Add-Content "$DesktopUnlockScripttPath" '$DriveToUnlock= (Get-BitLockerVolume | ?{$_.KeyProtector -ne $null}).mountpoint'
Add-Content "$DesktopUnlockScripttPath" '$BekVolumeDriveLetter = (Get-Volume -FileSystemLabel "Bek Volume").DriveLetter'
Add-Content "$DesktopUnlockScripttPath" '$BekPath = $BekVolumeDriveLetter + ":\*"'
Add-Content "$DesktopUnlockScripttPath" '$BekKeyName = (Get-ChildItem -Path $BekPath -Force -Include *.bek).Name'
Add-Content "$DesktopUnlockScripttPath" '$BekPath = $BekVolumeDriveLetter + ":\" + $BekKeyName'
Add-Content "$DesktopUnlockScripttPath" 'manage-bde -unlock $DriveToUnlock -recoveryKey "$BekPath"'
$UnlockStartupScript = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Unlock disk.ps1"
$UnlockStartupScriptpath = New-Item "C:\Unlock Disk\Unlock disk.ps1"
Add-Content "$UnlockStartupScriptpath" '$DriveToUnlock= (Get-BitLockerVolume | ?{$_.KeyProtector -ne $null}).mountpoint'
Add-Content "$UnlockStartupScriptpath" '$BekVolumeDriveLetter = (Get-Volume -FileSystemLabel "Bek Volume").DriveLetter'
Add-Content "$UnlockStartupScriptpath" '$BekPath = $BekVolumeDriveLetter + ":\*"'
Add-Content "$UnlockStartupScriptpath" '$BekKeyName = (Get-ChildItem -Path $BekPath -Force -Include *.bek).Name'
Add-Content "$UnlockStartupScriptpath" '$BekPath = $BekVolumeDriveLetter + ":\" + $BekKeyName'
Add-Content "$UnlockStartupScriptpath" 'manage-bde -unlock $DriveToUnlock -recoveryKey "$BekPath"'
#create .bat script stored in startup folder for all users, which will call the unlock script.ps1 when user log on and reboot of VM

$StartupFolderAllUsers = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$StartupUnlockDiskBatScriptPath = New-Item "$StartupFolderAllUsers\unlock_disk.bat"
Add-Content "$StartupUnlockDiskBatScriptPath" 'powershell.exe -windowstyle hidden -File "C:\Unlock Disk\Unlock disk.ps1"'
Stop-Transcript | Out-Null
