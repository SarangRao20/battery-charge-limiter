#Requires -RunAsAdministrator

$dest = "C:\EC-Tool"
$taskName = "Battery80Cap"
$svcName = "WinRing0_1_2_0"

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

# Defender exclusion
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
Add-MpPreference -ExclusionPath $dest -ErrorAction SilentlyContinue

# 1. Install/start WinRing0 kernel driver
if (Start-DriverService $svcName) {
    Write-Output "Driver already running"
} else {
    sc.exe create $svcName type= kernel start= auto binPath= "$dest\WinRing0x64.sys" | Out-Null
    sc.exe start $svcName | Out-Null
    Start-Sleep 1
    if (-not (Start-DriverService $svcName)) {
        Write-Error "WinRing0 service could not be started."
        exit 1
    }
}

# 2. Register scheduled task (AtLogon, highest, survives battery) -> runs app in tray
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
$action = New-ScheduledTaskAction -Execute "$dest\BatteryCapApp.exe" `
    -Argument "-tray"
$triggers = @( (New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME) )
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers `
    -Settings $settings -RunLevel Highest -Force | Out-Null

# 3. Test EC access
$test = & "$dest\EC-Access-Tool.exe" -winring0 -r 76 2>$null
if ($test -match "0x[0-9a-f]+") {
    Write-Output "EC access OK (register 0x76 = $($test.Trim()))"
} else {
    Write-Error "EC access failed: $test"
    exit 1
}

# 4. Launch app in system tray (dashboard shows, runs in background)
Start-Process "$dest\BatteryCapApp.exe"
