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
$ecHash     = "e1b274c59f975206c247e05b78387c6d5748019ad67a82bba4357a5e00c64f84"
$winringHash = "11bd2c9f9e2397c9a16e0990e4ed2cf0679498fe0fd418a3dfdac60b5c160ee5"
$rwdrvHash  = "d6384d3072b5d636cfe2ab056b2f53dd82997bdc16eba8132f1b734ba7a72b31"

function Verify-FileHash($path, $expected) {
    if (-not (Test-Path $path)) { return $false }
    $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower()
    return $actual -eq $expected.ToLower()
}

Write-Host "=== Battery Charge Limiter Setup ===" -ForegroundColor Cyan

# 1. Check/install driver (try RwDrv first — signed by Microsoft)
Write-Host "[1/5] Checking driver..." -NoNewline
$drv = $null
$useRwDrv = $false

# Check if RwDrv is already running
$rwService = Get-Service RwDrv -ErrorAction SilentlyContinue
if ($rwService -and $rwService.Status -eq "Running") {
    $useRwDrv = $true
    Write-Host " RwDrv OK" -ForegroundColor Green
} else {
    # Check if WinRing0 is already running
    $wrService = Get-Service WinRing0_1_2_0 -ErrorAction SilentlyContinue
    if ($wrService -and $wrService.Status -eq "Running") {
        Write-Host " WinRing0 OK" -ForegroundColor Green
    } else {
        Write-Host " NONE" -ForegroundColor Yellow
        Write-Host "Downloading EC-Access-Tool..." -NoNewline
        try {
            Invoke-WebRequest -Uri $ecUrl -OutFile "$env:TEMP\EC-Access-Tool.exe" -UseBasicParsing -ErrorAction Stop
            if (-not (Verify-FileHash "$env:TEMP\EC-Access-Tool.exe" $ecHash)) {
                Write-Host " HASH MISMATCH" -ForegroundColor Red
                Remove-Item "$env:TEMP\EC-Access-Tool.exe" -Force -ErrorAction SilentlyContinue
                exit 1
            }
            # Try RwDrv first (signed)
            try {
                Invoke-WebRequest -Uri $rwdrvUrl -OutFile "$env:TEMP\RwDrv.sys" -UseBasicParsing -ErrorAction Stop
                if (-not (Verify-FileHash "$env:TEMP\RwDrv.sys" $rwdrvHash)) {
                    Write-Host " RwDrv HASH MISMATCH" -ForegroundColor Red
                    Remove-Item "$env:TEMP\RwDrv.sys" -Force -ErrorAction SilentlyContinue
                    throw "hash mismatch"
                }
                sc.exe create RwDrv type= kernel binPath= "$env:TEMP\RwDrv.sys" | Out-Null
                sc.exe start RwDrv | Out-Null
                Start-Sleep 1
                $useRwDrv = $true
                Write-Host " RwDrv OK" -ForegroundColor Green
            } catch {
                # Fall back to WinRing0
                Invoke-WebRequest -Uri $winringUrl -OutFile "$env:TEMP\WinRing0x64.sys" -UseBasicParsing -ErrorAction Stop
                if (-not (Verify-FileHash "$env:TEMP\WinRing0x64.sys" $winringHash)) {
                    Write-Host " WinRing0 HASH MISMATCH" -ForegroundColor Red
                    Remove-Item "$env:TEMP\WinRing0x64.sys" -Force -ErrorAction SilentlyContinue
                    exit 1
                }
                & "$env:TEMP\EC-Access-Tool.exe" -install
                Start-Sleep 2
                $wrService = Get-Service WinRing0_1_2_0 -ErrorAction SilentlyContinue
                if (-not $wrService -or $wrService.Status -ne "Running") {
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
}

# 2. Create C:\EC-Tool and copy files
Write-Host "[2/5] Setting up C:\EC-Tool..." -NoNewline
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
Copy-Item "$env:TEMP\EC-Access-Tool.exe" "$dest\" -Force -ErrorAction SilentlyContinue
if ($useRwDrv) { Copy-Item "$env:TEMP\RwDrv.sys" "$dest\" -Force -ErrorAction SilentlyContinue }
Copy-Item "$env:TEMP\WinRing0x64.sys" "$dest\" -Force -ErrorAction SilentlyContinue
Copy-Item "$iconSrc\*.ico" "$iconDest\" -Force -ErrorAction SilentlyContinue
Copy-Item "$PSScriptRoot\daemon.ps1" "$dest\daemon.ps1" -Force -ErrorAction SilentlyContinue
Write-Host " OK" -ForegroundColor Green

# 3. Add Windows Defender exclusion
Write-Host "[3/5] Windows Defender exclusion..." -NoNewline
try {
    Add-MpPreference -ExclusionPath $dest -ErrorAction SilentlyContinue
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " SKIPPED" -ForegroundColor Yellow
}

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
