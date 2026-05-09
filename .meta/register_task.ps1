if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath)
    exit
}

# Remove legacy reference task if present (left over from prior My Study setup)
if (Get-ScheduledTask -TaskName 'MyStudyAutoPush' -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName 'MyStudyAutoPush' -Confirm:$false
    Write-Host "Removed legacy scheduled task 'MyStudyAutoPush'."
}

$autoPushPath = Join-Path $PSScriptRoot 'auto_push.ps1'

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
             -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$autoPushPath`""
$trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 2)
$trigger.Repetition.Duration = ''
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName 'MyTeachingAutoPush' `
                       -Action $action -Trigger $trigger `
                       -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Registered scheduled task 'MyTeachingAutoPush' (runs every 2h as SYSTEM)."
Write-Host "Auto-push script: $autoPushPath"
Write-Host ""
Write-Host "Press Enter to close."
Read-Host | Out-Null
