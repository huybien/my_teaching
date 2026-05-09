$taskName = 'MyTeachingAutoPush'
$logFile  = Join-Path $PSScriptRoot 'auto_push.log'

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "Task '$taskName' is NOT registered." -ForegroundColor Red
    Write-Host "Run register_task.bat (as admin) to register it."
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}

$info = $task | Get-ScheduledTaskInfo
$dur  = $task.Triggers[0].Repetition.Duration
if ([string]::IsNullOrEmpty($dur)) { $dur = 'indefinite' }

Write-Host "Task: $taskName" -ForegroundColor Green
Write-Host "  State:           $($task.State)"
Write-Host "  Principal:       $($task.Principal.UserId) ($($task.Principal.LogonType), $($task.Principal.RunLevel))"
Write-Host "  Action:          $($task.Actions[0].Execute) $($task.Actions[0].Arguments)"
Write-Host "  Trigger repeat:  every $($task.Triggers[0].Repetition.Interval), duration $dur"
Write-Host "  Last run:        $($info.LastRunTime)  (result=$($info.LastTaskResult))"
Write-Host "  Next run:        $($info.NextRunTime)"
Write-Host ""

if (Test-Path -LiteralPath $logFile) {
    Write-Host 'Last 10 log lines:' -ForegroundColor Cyan
    Get-Content -LiteralPath $logFile -Tail 10
} else {
    Write-Host "No log file yet at $logFile (script hasn't run)."
}

Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
