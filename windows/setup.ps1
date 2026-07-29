<#
.SYNOPSIS
    One-click setup for Battery Charge Limiter daemon
.DESCRIPTION
    Installs WinRing0 driver, copies EC-Access-Tool, registers scheduled task,
    and launches the daemon. Run as Administrator.
#>

#Requires -RunAsAdministrator

$repoRoot   = Split-Path $PSScriptRoot -Parent
$dest       = "C:\EC-Tool"
$daemonPath = "$PSScriptRoot\daemon.ps1"
$iconSrc    = "$PSScriptRoot\icons"
$iconDest   = "$dest"
$ecUrl      = "https://github.com/JamesH65/EC-Access-Tool/raw/master/bin/Release/EC-Access-Tool.exe"
$driverUrl  = "https://github.com/JamesH65/EC-Access-Tool/raw/master/WinRing0/WinRing0x64.sys"

Write-Host "=== Battery Charge Limiter Setup ===" -ForegroundColor Cyan

# 1. Check if WinRing0 driver is running
Write-Host "[1/5] Checking WinRing0 driver..." -NoNewline
$drv = Get-Service WinRing0_1_2_0 -ErrorAction SilentlyContinue
if ($drv -and $drv.Status -eq "Running") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " NOT INSTALLED" -ForegroundColor Yellow
    Write-Host "Downloading EC-Access-Tool..." -NoNewline
    try {
        Invoke-WebRequest -Uri $ecUrl -OutFile "$env:TEMP\EC-Access-Tool.exe" -UseBasicParsing -ErrorAction Stop
        Invoke-WebRequest -Uri $driverUrl -OutFile "$env:TEMP\WinRing0x64.sys" -UseBasicParsing -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    } catch {
        Write-Host " FAILED (manual download needed)" -ForegroundColor Red
        Write-Host "Download from: https://github.com/JamesH65/EC-Access-Tool/releases"
        exit 1
    }
    & "$env:TEMP\EC-Access-Tool.exe" -install
    Start-Sleep 2
    $drv = Get-Service WinRing0_1_2_0 -ErrorAction SilentlyContinue
    if (-not $drv -or $drv.Status -ne "Running") {
        Write-Host "Driver installation failed. Try manual install:" -ForegroundColor Red
        Write-Host "  $env:TEMP\EC-Access-Tool.exe -install"
        exit 1
    }
}

# 2. Create C:\EC-Tool and copy files
Write-Host "[2/5] Setting up C:\EC-Tool..." -NoNewline
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
Copy-Item "$env:TEMP\EC-Access-Tool.exe" "$dest\" -Force -ErrorAction SilentlyContinue
Copy-Item "$env:TEMP\WinRing0x64.sys" "$dest\" -Force -ErrorAction SilentlyContinue
Copy-Item "$iconSrc\*.ico" "$iconDest\" -Force -ErrorAction SilentlyContinue
Copy-Item "$PSScriptRoot\daemon.ps1" "$dest\daemon.ps1" -Force -ErrorAction SilentlyContinue
Write-Host " OK" -ForegroundColor Green

# 3. Add Windows Defender exclusion (Prevents WinRing0 from being flagged)
Write-Host "[3/5] Windows Defender exclusion..." -NoNewline
try {
    Add-MpPreference -ExclusionPath $dest -ErrorAction SilentlyContinue
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " SKIPPED (admin may be needed)" -ForegroundColor Yellow
}

# 4. Register scheduled task
Write-Host "[4/5] Registering scheduled task..." -NoNewline
$taskName = "Battery80Cap"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File $dest\daemon.ps1"
$triggers = @(
    (New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME)
)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers `
    -Settings $settings -RunLevel Highest -Force | Out-Null
Write-Host " OK" -ForegroundColor Green

# 5. Test EC access and launch
Write-Host "[5/5] Testing EC access..." -NoNewline
try {
    $test = & "$dest\EC-Access-Tool.exe" -winring0 -r 76 2>$null
    if ($test -match "0x[0-9a-f]+") {
        Write-Host " OK (register 0x76 = $($test.Trim()))" -ForegroundColor Green
    } else {
        Write-Host " UNEXPECTED OUTPUT: $test" -ForegroundColor Yellow
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

Write-Host "`nSetup complete! Launching daemon..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File $dest\daemon.ps1" -WindowStyle Hidden
Write-Host "Daemon running in system tray. Icon:" -NoNewline
Write-Host " Green = charging (< $stopAt%),  Red = inhibited (at $stopAt%),  Gray = discharging" -ForegroundColor DarkGray
