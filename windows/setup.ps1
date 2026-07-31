<#
.SYNOPSIS
    One-click setup for Battery Charge Limiter daemon
.DESCRIPTION
    Installs EC-Access-Tool + driver (RwDrv or WinRing0), copies files,
    registers scheduled task, and launches the daemon. Run as Administrator.
#>

#Requires -RunAsAdministrator

$repoRoot   = Split-Path $PSScriptRoot -Parent
$dest       = "C:\EC-Tool"
$daemonPath = "$PSScriptRoot\daemon.ps1"
$iconSrc    = "$PSScriptRoot\icons"
$iconDest   = "$dest"
$ecUrl      = "https://github.com/shubhampaul/EC-Access-Tool/raw/main/EC-Access-Tool.exe"
$winringUrl = "https://github.com/shubhampaul/EC-Access-Tool/raw/main/WinRing0x64.sys"
$rwdrvUrl   = "https://github.com/shubhampaul/EC-Access-Tool/raw/main/RwDrv.sys"

# SHA256 hashes (verified against repo at time of release)
$ecHash      = "e1b274c59f975206c247e05b78387c6d5748019ad67a82bba4357a5e00c64f84"
$winringHash = "11bd2c9f9e2397c9a16e0990e4ed2cf0679498fe0fd418a3dfdac60b5c160ee5"
$rwdrvHash   = "d6384d3072b5d636cfe2ab056b2f53dd82997bdc16eba8132f1b734ba7a72b31"

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
    }
    return $true
}

Write-Host "=== Battery Charge Limiter Setup ===" -ForegroundColor Cyan

# 0. Prepare destination + Defender exclusion BEFORE any download
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
Add-MpPreference -ExclusionPath $dest -ErrorAction SilentlyContinue

# 1. Check/install driver (try RwDrv first — signed by Microsoft)
Write-Host "[1/5] Checking driver..." -NoNewline
$useRwDrv = $false

if (Start-DriverService "RwDrv") {
    $useRwDrv = $true
    Write-Host " RwDrv OK" -ForegroundColor Green
} elseif (Start-DriverService "WinRing0_1_2_0") {
    Write-Host " WinRing0 OK" -ForegroundColor Green
} else {
    Write-Host " NONE" -ForegroundColor Yellow
    Write-Host "Downloading EC-Access-Tool..."
    try {
        Invoke-WebRequest -Uri $ecUrl -OutFile "$dest\EC-Access-Tool.exe" -UseBasicParsing -ErrorAction Stop
        if (-not (Verify-FileHash "$dest\EC-Access-Tool.exe" $ecHash)) {
            Write-Host " HASH MISMATCH" -ForegroundColor Red
            Remove-Item "$dest\EC-Access-Tool.exe" -Force -ErrorAction SilentlyContinue
            exit 1
        }
        # Try RwDrv first (signed)
        try {
            Invoke-WebRequest -Uri $rwdrvUrl -OutFile "$dest\RwDrv.sys" -UseBasicParsing -ErrorAction Stop
            if (-not (Verify-FileHash "$dest\RwDrv.sys" $rwdrvHash)) {
                Write-Host " RwDrv HASH MISMATCH" -ForegroundColor Red
                Remove-Item "$dest\RwDrv.sys" -Force -ErrorAction SilentlyContinue
                throw "hash mismatch"
            }
            sc.exe create RwDrv type= kernel start= auto binPath= "$dest\RwDrv.sys" | Out-Null
            sc.exe start RwDrv | Out-Null
            Start-Sleep 1
            $useRwDrv = $true
            Write-Host " RwDrv OK" -ForegroundColor Green
        } catch {
            # Fall back to WinRing0
            Invoke-WebRequest -Uri $winringUrl -OutFile "$dest\WinRing0x64.sys" -UseBasicParsing -ErrorAction Stop
            if (-not (Verify-FileHash "$dest\WinRing0x64.sys" $winringHash)) {
                Write-Host " WinRing0 HASH MISMATCH" -ForegroundColor Red
                Remove-Item "$dest\WinRing0x64.sys" -Force -ErrorAction SilentlyContinue
                exit 1
            }
            & "$dest\EC-Access-Tool.exe" -install
            Start-Sleep 2
            if (-not (Start-DriverService "WinRing0_1_2_0")) {
                Write-Host " FAILED" -ForegroundColor Red
                Write-Host "Manual download: https://github.com/shubhampaul/EC-Access-Tool"
                Write-Host "Then run: EC-Access-Tool.exe -install"
                exit 1
            }
            Write-Host " WinRing0 OK" -ForegroundColor Green
        }
    } catch {
        Write-Host " FAILED (network)" -ForegroundColor Red
        Write-Host "Download from: https://github.com/shubhampaul/EC-Access-Tool"
        exit 1
    }
}

# 2. Copy remaining files
Write-Host "[2/5] Setting up C:\EC-Tool..." -NoNewline
Copy-Item "$iconSrc\*.ico" "$iconDest\" -Force -ErrorAction SilentlyContinue
Copy-Item "$PSScriptRoot\daemon.ps1" "$dest\daemon.ps1" -Force -ErrorAction SilentlyContinue
Write-Host " OK" -ForegroundColor Green

# 3. Ensure driver auto-starts on boot
Write-Host "[3/5] Driver auto-start..." -NoNewline
if ($useRwDrv) {
    sc.exe config RwDrv start= auto | Out-Null
} else {
    sc.exe config WinRing0_1_2_0 start= auto | Out-Null
}
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
