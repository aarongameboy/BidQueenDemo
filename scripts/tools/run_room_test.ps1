# 房间 N 人出价同步自动化测试（默认依次测 2 / 3 / 4 人）
param(
    [int]$PlayerCount = 0
)

$ErrorActionPreference = "Continue"
$godot = "D:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe"
$proj = "D:\bidKingDemo"
$scene = "res://scenes/tools/test_room_network.tscn"
$logDir = Join-Path $proj "test_logs"
$env:BIDKING_ROOM_TEST = "1"

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

function Invoke-RoomTest {
    param([int]$N)
    Write-Host ""
    Write-Host "========== Room test: $N players ==========" -ForegroundColor Cyan
    Remove-Item (Join-Path $proj ".room_test_session.json") -ErrorAction SilentlyContinue
    $commonArgs = @("--headless", "--path", $proj, $scene, "--", "--room-test=host", "--players=$N")
    $hostLog = Join-Path $logDir "host_${N}p.log"
    $hostErr = Join-Path $logDir "host_${N}p.err"
    $hp = Start-Process -FilePath $godot -ArgumentList $commonArgs -PassThru -NoNewWindow `
        -RedirectStandardOutput $hostLog -RedirectStandardError $hostErr
    Start-Sleep -Seconds 2

    $clientProcs = @()
    for ($i = 1; $i -lt $N; $i++) {
        $cLog = Join-Path $logDir "client${i}_${N}p.log"
        $cErr = Join-Path $logDir "client${i}_${N}p.err"
        $cp = Start-Process -FilePath $godot -ArgumentList @(
            "--headless", "--path", $proj, $scene, "--", "--room-test=client", "--players=$N"
        ) -PassThru -NoNewWindow -RedirectStandardOutput $cLog -RedirectStandardError $cErr
        $clientProcs += @{ Proc = $cp; Log = $cLog; Err = $cErr; Id = $i }
        Start-Sleep -Seconds 1
    }

    foreach ($c in $clientProcs) {
        if (-not $c.Proc.HasExited) {
            Wait-Process -Id $c.Proc.Id -Timeout 180 -ErrorAction SilentlyContinue
        }
        $c.Proc.Refresh()
    }
    if ($hp -and -not $hp.HasExited) {
        Wait-Process -Id $hp.Id -Timeout 180 -ErrorAction SilentlyContinue
    }
    if ($hp -and -not $hp.HasExited) { $hp.Kill() }
    $hp.Refresh()

    $failed = $false
    if ((Get-Content $hostErr -Raw -ErrorAction SilentlyContinue) -match "FAIL:") { $failed = $true }
    Get-Content $hostLog, $hostErr -ErrorAction SilentlyContinue | Select-Object -Last 8
    foreach ($c in $clientProcs) {
        if ((Get-Content $c.Err -Raw -ErrorAction SilentlyContinue) -match "FAIL:") { $failed = $true }
        Write-Host "--- client$($c.Id) ---"
        Get-Content $c.Log, $c.Err -ErrorAction SilentlyContinue | Select-Object -Last 5
        if ($c.Proc.ExitCode -ne 0 -and $null -ne $c.Proc.ExitCode) { $failed = $true }
    }
    if ($failed -or ((Get-Content $hostLog -Raw -ErrorAction SilentlyContinue) -notmatch '\[room-test:host\]')) {
        Write-Host "FAIL: $N players" -ForegroundColor Red
        return $false
    }
    if ((Get-Content $hostLog -Raw -ErrorAction SilentlyContinue) -notmatch 'all_locked.: true') {
        Write-Host "FAIL: $N players (no all_locked)" -ForegroundColor Red
        return $false
    }
    Write-Host "PASS: $N players" -ForegroundColor Green
    return $true
}

$counts = if ($PlayerCount -ge 2 -and $PlayerCount -le 4) { @($PlayerCount) } else { @(2, 3, 4) }
$allOk = $true
foreach ($n in $counts) {
    if (-not (Invoke-RoomTest -N $n)) { $allOk = $false }
}
if (-not $allOk) { exit 1 }
Write-Host ""
Write-Host "ALL PASSED: 2/3/4 players" -ForegroundColor Green
exit 0
