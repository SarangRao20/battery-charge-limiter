<#
.SYNOPSIS
    One-click setup for Battery Charge Limiter daemon
.DESCRIPTION
    Installs the EC-Access-Tool + driver (vendored in drivers/), copies files,
    registers scheduled task, and launches the daemon. Run as Administrator.
    No third-party downloads at install time.
#>

#Requires -RunAsAdministrator

$repoRoot   = Split-Path $PSScriptRoot -Parent
$dest       = "C:\EC-Tool"
$drvSrc     = "$PSScriptRoot\drivers"
$iconSrc    = "$PSScriptRoot\icons"
$daemonPath = "$PSScriptRoot\daemon.ps1"

# SHA256 of vendored files (see drivers/README.md)
$ecHash     = "504a58b1faba08b25a45d51de5996bf7cb31f461e28f1a270d2e53b1f3fda8ac"
$winringHash = "11bd2c9f9e2397c9a16e0990e4ed2cf0679498fe0fd418a3dfdac60b5c160ee5"

function Verify-FileHash($path, $expected) {
    if (-not (Test-Path $path)) { return $false }
    $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower()
    return $actual -eq $expected.ToLower()
}

function Start-DriverService($name) {
    $svc = Get-Service $name -ErrorAction SilentlyContinue
    if (-not $svc) { return $false }
    if ($svc.Status -ne "Running") {
        sc.exe start $name | Out-Null
        Start-Sleep 1
        $svc = Get-Service $name -ErrorAction SilentlyContinue
    }
    return ($svc.Status -eq "Running")
}

Write-Host "=== Battery Charge Limiter Setup ===" -ForegroundColor Cyan

# 0. Prepare destination + Defender exclusion
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
Add-MpPreference -ExclusionPath $dest -ErrorAction SilentlyContinue

# 1. Verify vendored files
Write-Host "[1/5] Verifying vendored files..." -NoNewline
$ecPath = "$drvSrc\EC-Access-Tool.exe"
$winringPath = "$drvSrc\WinRing0x64.sys"
if (-not (Test-Path $ecPath)) {
    Write-Host " EC-Access-Tool.exe NOT FOUND" -ForegroundColor Red
    Write-Host "Was it quarantined by Defender? Check Windows Security > Virus & threat protection."
    exit 1
}
if (-not (Verify-FileHash $ecPath $ecHash)) {
    Write-Host " EC-Access-Tool.exe HASH MISMATCH" -ForegroundColor Red
    Write-Host "Expected SHA256: $ecHash"
    Write-Host "Re-download from the repo or restore from Defender quarantine."
    exit 1
}
if (-not (Test-Path $winringPath)) {
    Write-Host " WinRing0x64.sys NOT FOUND" -ForegroundColor Red
    Write-Host "WinRing0 is sometimes flagged as a 'HackTool' by Defender."
    Write-Host "Allow it: Windows Security > Protection history > Allow on device."
    exit 1
}
if (-not (Verify-FileHash $winringPath $winringHash)) {
    Write-Host " WinRing0x64.sys HASH MISMATCH" -ForegroundColor Red
    Write-Host "Expected SHA256: $winringHash"
    Write-Host "Re-download from the repo or restore from Defender quarantine."
    exit 1
}
Write-Host " OK" -ForegroundColor Green

# 2. Driver setup (prefer local RwDrv if present, else WinRing0)
Write-Host "[2/5] Installing driver..." -NoNewline
$useRwDrv = $false

$rwdrvLocal = "$drvSrc\RwDrv.sys"
if (Start-DriverService "RwDrv") {
    $useRwDrv = $true
    Write-Host " RwDrv OK (already running)" -ForegroundColor Green
} elseif (Test-Path $rwdrvLocal) {
    # RwDrv present but not installed -> copy first, then install
    Copy-Item $rwdrvLocal "$dest\RwDrv.sys" -Force
    sc.exe create RwDrv type= kernel start= auto binPath= "$dest\RwDrv.sys" | Out-Null
    sc.exe start RwDrv | Out-Null
    Start-Sleep 1
    $useRwDrv = $true
    Write-Host " RwDrv OK" -ForegroundColor Green
} elseif (Start-DriverService "WinRing0_1_2_0") {
    Write-Host " WinRing0 OK (already running)" -ForegroundColor Green
} else {
    # Install WinRing0 from vendored copy
    Copy-Item $ecPath "$dest\EC-Access-Tool.exe" -Force
    Copy-Item $winringPath "$dest\WinRing0x64.sys" -Force
    & "$dest\EC-Access-Tool.exe" -install
    Start-Sleep 2
    if (-not (Start-DriverService "WinRing0_1_2_0")) {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "WinRing0 service could not be started."
        exit 1
    }
    Write-Host " WinRing0 OK" -ForegroundColor Green
}

# 3. Copy files to C:\EC-Tool
Write-Host "[3/5] Setting up C:\EC-Tool..." -NoNewline
Copy-Item $ecPath "$dest\EC-Access-Tool.exe" -Force
Copy-Item $winringPath "$dest\WinRing0x64.sys" -Force
if ($useRwDrv) { Copy-Item $rwdrvLocal "$dest\RwDrv.sys" -Force -ErrorAction SilentlyContinue }
Copy-Item "$iconSrc\*.ico" "$dest\" -Force -ErrorAction SilentlyContinue
Copy-Item $daemonPath "$dest\daemon.ps1" -Force
Write-Host " OK" -ForegroundColor Green

# 4. Register scheduled task
Write-Host "[4/5] Registering scheduled task..." -NoNewline
$taskName = "Battery80Cap"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File $dest\daemon.ps1"
$triggers = @( (New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME) )
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers `
    -Settings $settings -RunLevel Highest -Force | Out-Null
Write-Host " OK" -ForegroundColor Green

# 5. Test EC access and launch
Write-Host "[5/5] Testing EC access..." -NoNewline
$driverFlag = if ($useRwDrv) { "-rwdrv" } else { "-winring0" }
try {
    $test = & "$dest\EC-Access-Tool.exe" $driverFlag -r 76 2>$null
    if ($test -match "0x[0-9a-f]+") {
        Write-Host " OK (register 0x76 = $($test.Trim()))" -ForegroundColor Green
    } else {
        Write-Host " UNEXPECTED: $test" -ForegroundColor Yellow
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

Write-Host "`nSetup complete! Launching daemon..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File $dest\daemon.ps1" -WindowStyle Hidden
Write-Host "Daemon running in system tray." -ForegroundColor DarkGray
