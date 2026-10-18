$task='GamePowerAuto'
Stop-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
Write-Host 'Task removed. To restore original power plan: .\GamePowerAuto.ps1 -Restore'
