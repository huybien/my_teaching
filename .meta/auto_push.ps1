$repoRoot  = Split-Path -Parent $PSScriptRoot
$logFile   = Join-Path $PSScriptRoot 'auto_push.log'
$lockFile  = Join-Path $PSScriptRoot 'auto_push.lock'
$tokenFile = Join-Path $PSScriptRoot 'github_info.txt'
$git       = 'C:\Program Files\Git\bin\git.exe'

function Write-Log([string]$msg) {
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    Add-Content -LiteralPath $logFile -Value "$ts | $msg"
}

function Get-ConfigField([string[]]$lines, [string]$field) {
    $line = $lines | Where-Object { $_ -match "^${field}:" } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace "^${field}:\s*", '').Trim()
}

if (Test-Path -LiteralPath $lockFile) {
    Write-Log 'skip: lockfile present (concurrent run)'
    exit 0
}
New-Item -ItemType File -Path $lockFile -Force | Out-Null

try {
    Set-Location -LiteralPath $repoRoot
    $base   = (Resolve-Path -LiteralPath $repoRoot).Path
    $gitPre = @('-c', "safe.directory=$base")

    if (-not (Test-Path -LiteralPath '.git')) {
        Write-Log "error: not a git repo at $base"; exit 1
    }
    if (-not (Test-Path -LiteralPath $tokenFile)) {
        Write-Log 'error: github_info.txt missing'; exit 1
    }

    $cfgLines = Get-Content -LiteralPath $tokenFile
    $username = Get-ConfigField $cfgLines 'Username'
    $token    = Get-ConfigField $cfgLines 'Token'
    $repo     = Get-ConfigField $cfgLines 'Remote repository name'
    if (-not $username) { Write-Log 'error: no Username: line in github_info.txt'; exit 1 }
    if (-not $token)    { Write-Log 'error: no Token: line in github_info.txt';    exit 1 }
    if (-not $repo)     { Write-Log 'error: no "Remote repository name:" line in github_info.txt'; exit 1 }

    $folders = Get-ChildItem -LiteralPath $base -Directory -Force |
               Where-Object { $_.Name -notmatch '^\.' } |
               ForEach-Object { $_.Name }

    $diskPaths = foreach ($f in $folders) {
        Get-ChildItem -LiteralPath (Join-Path $base $f) -Filter *.pptx -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '~$*' } |
            ForEach-Object { ($_.FullName.Substring($base.Length + 1)) -replace '\\','/' }
    }
    $trackedPaths = @(& $git @gitPre ls-files -- '*.pptx')
    $allPaths = @(@($diskPaths) + $trackedPaths) | Sort-Object -Unique
    if (-not $allPaths -or $allPaths.Count -eq 0) {
        Write-Log 'no pptx paths to consider'; exit 0
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllLines($tmp, $allPaths)
    & $git @gitPre add -A --pathspec-from-file=$tmp
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue

    & $git @gitPre diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'no changes'; exit 0
    }

    $changedFiles = @(& $git @gitPre diff --cached --name-only)
    $count = $changedFiles.Count
    $msg = "Auto-update pptx $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    & $git @gitPre commit -m $msg | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "error: commit failed (exit $LASTEXITCODE)"; exit 1
    }

    $pushUrl = "https://${username}:$token@github.com/$username/$repo.git"
    $pushOut = & $git @gitPre push $pushUrl 'main:main' 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Log "error: push failed (exit $LASTEXITCODE) -- $($pushOut.Trim())"
        exit 1
    }

    Write-Log "ok: committed+pushed $count file(s) to $username/$repo"
}
catch {
    Write-Log "error: $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item -LiteralPath $lockFile -ErrorAction SilentlyContinue
}
