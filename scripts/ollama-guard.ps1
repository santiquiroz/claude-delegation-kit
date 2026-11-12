# Stops Ollama while a game or an editing program runs, so the GPU and its VRAM are free,
# and starts it again once that program has been closed for a while.
# Rules live in ollama-guard.rules.txt next to this script and are re-read on every check.
# Windows PowerShell 5.1 compatible: the logon task runs powershell.exe. Keep this file ASCII.
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$SelfTest,
    [switch]$Check
)

$TaskName = 'ollama-guard'
$PollSeconds = 5
$ResumeAfterSeconds = 20
$ReadySeconds = 30
$RulesPath = Join-Path $PSScriptRoot 'ollama-guard.rules.txt'
$LogPath = Join-Path $PSScriptRoot 'ollama-guard.log'
$OllamaDir = "$env:LOCALAPPDATA\Programs\Ollama"
$OllamaUrl = 'http://127.0.0.1:11434'
$ClaudeMemResumeUrl = 'http://127.0.0.1:37777/api/processing'

function ConvertTo-GuardRules([string[]]$Lines) {
    $include = @()
    $exclude = @()
    foreach ($raw in $Lines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line.StartsWith('!')) { $exclude += $line.Substring(1).Trim() } else { $include += $line }
    }
    @{ Include = $include; Exclude = $exclude }
}

function Test-RuleMatch([string]$Rule, [string]$Name, [string]$Path) {
    if ($Rule.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) { return $Rule -eq $Name }
    if (-not $Path) { return $false }
    $Path.IndexOf("\$($Rule.Trim('\'))\", [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Test-HeavyProcess([string]$Name, [string]$Path, $Rules) {
    foreach ($rule in $Rules.Exclude) { if (Test-RuleMatch $rule $Name $Path) { return $false } }
    foreach ($rule in $Rules.Include) { if (Test-RuleMatch $rule $Name $Path) { return $true } }
    $false
}

function Get-GuardAction([bool]$HeavyRunning, [bool]$PausedByGuard, [bool]$OllamaRunning, [int]$QuietSeconds) {
    if ($HeavyRunning -and $OllamaRunning -and -not $PausedByGuard) { return 'pause' }
    if ($PausedByGuard -and -not $HeavyRunning -and $QuietSeconds -ge $ResumeAfterSeconds) { return 'resume' }
    'none'
}

function Read-GuardRules {
    ConvertTo-GuardRules (Get-Content -LiteralPath $RulesPath)
}

function Find-HeavyProcesses($Rules) {
    $names = Get-Process | Where-Object { Test-HeavyProcess "$($_.ProcessName).exe" $_.Path $Rules } |
        ForEach-Object { "$($_.ProcessName).exe" }
    @($names | Sort-Object -Unique)
}

function Get-OllamaProcesses {
    Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith("$OllamaDir\", [StringComparison]::OrdinalIgnoreCase) }
}

function Stop-Ollama {
    # the tray app relaunches the server when it dies, so it goes first
    Get-Process -Name 'ollama app' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-OllamaProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Sync-OllamaEnvironment {
    # this task's environment dates from logon; Corral may have changed the OLLAMA_* user variables since
    Get-ChildItem Env: | Where-Object Name -like 'OLLAMA_*' | ForEach-Object { Remove-Item "Env:$($_.Name)" }
    $saved = Get-ItemProperty -Path 'HKCU:\Environment'
    $saved.PSObject.Properties | Where-Object Name -like 'OLLAMA_*' | ForEach-Object { Set-Item "Env:$($_.Name)" $_.Value }
}

function Wait-OllamaReady {
    $deadline = (Get-Date).AddSeconds($ReadySeconds)
    while ((Get-Date) -lt $deadline) {
        try { Invoke-RestMethod "$OllamaUrl/api/version" -TimeoutSec 2 | Out-Null; return $true } catch { Start-Sleep -Seconds 1 }
    }
    $false
}

function Resume-ClaudeMemQueue {
    try {
        Invoke-RestMethod -Method Post $ClaudeMemResumeUrl -ContentType 'application/json' -Body '{"isProcessing":false}' -TimeoutSec 5 | Out-Null
    } catch { }
}

function Start-Ollama {
    Sync-OllamaEnvironment
    Start-Process -FilePath (Join-Path $OllamaDir 'ollama app.exe')
    $ready = Wait-OllamaReady
    Resume-ClaudeMemQueue
    $ready
}

function Write-GuardLog([string]$Message) {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Invoke-GuardStep($State) {
    $heavy = Find-HeavyProcesses (Read-GuardRules)
    if ($heavy.Count) { $State.LastHeavy = Get-Date }
    $quiet = [int]((Get-Date) - $State.LastHeavy).TotalSeconds
    $action = Get-GuardAction ($heavy.Count -gt 0) $State.PausedByGuard ([bool](Get-OllamaProcesses)) $quiet
    if ($action -eq 'pause') {
        Stop-Ollama
        $State.PausedByGuard = $true
        Write-GuardLog "paused Ollama: $($heavy -join ', ') running"
    }
    if ($action -eq 'resume') {
        $State.PausedByGuard = $false
        Write-GuardLog "resumed Ollama (ready: $(Start-Ollama))"
    }
}

function Invoke-GuardLoop {
    $state = @{ PausedByGuard = $false; LastHeavy = Get-Date }
    Write-GuardLog 'guard started'
    while ($true) {
        try { Invoke-GuardStep $state } catch { Write-GuardLog "error: $($_.Exception.Message)" }
        Start-Sleep -Seconds $PollSeconds
    }
}

function Assert-NothingHeavyRunning {
    $heavy = Find-HeavyProcesses (Read-GuardRules)
    if (-not $heavy.Count) { return }
    # an always-on helper matched here would keep Ollama stopped forever
    throw "Matching the rules right now: $($heavy -join ', '). Close them, or exclude each with a line '!<name>.exe' in $RulesPath, then install again."
}

function Register-GuardTask {
    Assert-NothingHeavyRunning
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' registered and started. Log: $LogPath"
}

function Unregister-GuardTask {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Task '$TaskName' removed."
}

function Assert-Same($Expected, $Actual, [string]$Label) {
    if ($Expected -eq $Actual) { return 0 }
    Write-Host "FAIL $Label`: expected '$Expected', got '$Actual'"
    1
}

function Invoke-SelfTest {
    $rules = Read-GuardRules
    $steam = 'D:\SteamLibrary\steamapps\common\ELDEN RING\Game\eldenring.exe'
    $wallpaper = 'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe'
    $launcher = 'C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'
    $eos = 'C:\Program Files (x86)\Epic Games\Epic Online Services\managedArtifacts\98bc\EOSOverlayRenderer-Win64-Shipping.exe'
    $fortnite = 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
    $failed = 0
    $failed += Assert-Same $true (Test-HeavyProcess 'eldenring.exe' $steam $rules) 'steam game'
    $failed += Assert-Same $false (Test-HeavyProcess 'wallpaper32.exe' $wallpaper $rules) 'wallpaper engine excluded'
    $failed += Assert-Same $false (Test-HeavyProcess 'EpicGamesLauncher.exe' $launcher $rules) 'epic launcher excluded'
    $failed += Assert-Same $false (Test-HeavyProcess 'EOSOverlayRenderer-Win64-Shipping.exe' $eos $rules) 'epic online services excluded'
    $failed += Assert-Same $true (Test-HeavyProcess 'FortniteClient-Win64-Shipping.exe' $fortnite $rules) 'epic game'
    $failed += Assert-Same $true (Test-HeavyProcess 'RESOLVE.exe' $null $rules) 'editor by name, any case, no path'
    $failed += Assert-Same $false (Test-HeavyProcess 'steam.exe' 'C:\Program Files (x86)\Steam\steam.exe' $rules) 'steam client'
    $failed += Assert-Same $false (Test-HeavyProcess 'notepad.exe' 'C:\Windows\notepad.exe' $rules) 'ordinary program'
    $failed += Assert-Same 'pause' (Get-GuardAction $true $false $true 0) 'game starts while Ollama runs'
    $failed += Assert-Same 'none' (Get-GuardAction $true $false $false 0) 'Ollama was already stopped'
    $failed += Assert-Same 'none' (Get-GuardAction $true $true $true 0) 'user restarted Ollama during the game'
    $failed += Assert-Same 'none' (Get-GuardAction $false $true $false 10) 'game closed moments ago'
    $failed += Assert-Same 'resume' (Get-GuardAction $false $true $false 25) 'game closed long enough'
    $failed += Assert-Same 'none' (Get-GuardAction $false $false $true 99) 'nothing to do'
    if ($failed) { Write-Host "$failed self-test check(s) failed"; exit 1 }
    Write-Host 'ollama-guard self-test passed'
}

function Show-GuardCheck {
    $heavy = Find-HeavyProcesses (Read-GuardRules)
    if (-not $heavy.Count) { $heavy = @('none') }
    Write-Host "heavy processes: $($heavy -join ', ')"
    Write-Host "ollama running: $([bool](Get-OllamaProcesses))"
    Write-Host "task: $((Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue).State)"
}

if ($SelfTest) { Invoke-SelfTest; exit 0 }
if ($Check) { Show-GuardCheck; exit 0 }
if ($Install) { Register-GuardTask; exit 0 }
if ($Uninstall) { Unregister-GuardTask; exit 0 }
Invoke-GuardLoop
