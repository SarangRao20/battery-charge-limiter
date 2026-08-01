<#
.SYNOPSIS
    Battery Charge Limiter Daemon
.DESCRIPTION
    Monitors battery charge level and inhibits charging at 80%
    by writing EC register 0x76 (0x40=auto/charge, 0x45=stop).
    Uses WinRing0 or RwDrv driver for EC access.
.NOTES
    Run: powershell -STA -WindowStyle Hidden -File daemon.ps1
    Tested: HP Pavilion 15-eg3xxx
#>

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# === SINGLE INSTANCE ===
$mutex = New-Object System.Threading.Mutex($false, "Global\BatteryChargeLimiter_{7B1E4A2C-6B3D-4F2E-9A1C-8D5E7F3B2A1C}")
if (-not $mutex.WaitOne(0, $false)) { $mutex.Dispose(); exit 0 }

# === CONFIG ===
$ecTool     = "C:\EC-Tool\EC-Access-Tool.exe"
$regAddr    = "76"
$autoVal    = "40"
$inhibitVal = "45"
$stopAt     = 80
$iconDir    = if (Test-Path "$PSScriptRoot\icons") { "$PSScriptRoot\icons" } else { "C:\EC-Tool" }
$driver     = if ((Get-Service RwDrv -ErrorAction SilentlyContinue).Status -eq "Running") { "-rwdrv" } else { "-winring0" }

# === ICONS ===
$greenIcon = [System.Drawing.Icon]::ExtractAssociatedIcon("$iconDir\green.ico")
$redIcon   = [System.Drawing.Icon]::ExtractAssociatedIcon("$iconDir\red.ico")
$grayIcon  = [System.Drawing.Icon]::ExtractAssociatedIcon("$iconDir\gray.ico")

# === TRAY ===
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Text = "Battery Cap $stopAt%"
$tray.Visible = $true
$tray.Icon = $greenIcon

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$itemStatus = New-Object System.Windows.Forms.ToolStripMenuItem("Check Status")
$itemBypass = New-Object System.Windows.Forms.ToolStripMenuItem("Bypass - Full Charge")
$itemSep    = New-Object System.Windows.Forms.ToolStripSeparator
$itemExit   = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
$menu.Items.AddRange(@($itemStatus, $itemBypass, $itemSep, $itemExit))
$tray.ContextMenuStrip = $menu

$inhibited = $false
$bypassed  = $false

# === MENU EVENTS ===
$itemStatus.add_Click({
    $v = & $ecTool $driver -r $regAddr
    $b = Get-WmiObject Win32_Battery
    $val = $v.Trim()
    $s = if ($val -eq "0xc5" -or $val -eq "0x45") { "INHIBITED" } else { "AUTO" }
    $ac = if ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 1) { "Plugged" } else { "On Battery" }
    $design = (Get-CimInstance Win32_PortableBattery -ErrorAction SilentlyContinue).DesignCapacity
    $full = (Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue).FullChargedCapacity
    $health = if ($design -and $full) { [math]::Round(($full / $design) * 100) } else { "?" }
    [System.Windows.Forms.MessageBox]::Show(
        "EC reg 0x$regAddr : $val  ($s)`nBattery  : $($b.EstimatedChargeRemaining)%`nHealth   : $health%  ($full/$design mWh)`nStatus   : $($b.BatteryStatus)`nAC       : $ac`nRuntime  : $($b.EstimatedRunTime) min",
        "Battery Cap"
    )
})

$itemBypass.add_Click({
    if ($bypassed) {
        $bypassed = $false
        $itemBypass.Text = "Bypass - Full Charge"
        $tray.ShowBalloonTip(3000, "Battery Cap", "Protection enabled (stop at ${stopAt}%)", 1)
    } else {
        & $ecTool $driver -w $regAddr $autoVal | Out-Null
        $inhibited = $false; $bypassed = $true
        $itemBypass.Text = "Cancel Bypass"
        $tray.Icon = $greenIcon
        $tray.ShowBalloonTip(3000, "Battery Cap", "Bypass enabled - will charge to 100%", 1)
    }
})

$itemExit.add_Click({
    $tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
    Stop-Process -Id $pid -Force
})

# === TIMER (500ms) ===
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.add_Tick({
    if ($bypassed) { return }

    $b = Get-WmiObject Win32_Battery -ErrorAction SilentlyContinue
    if (-not $b) { return }
    $charge = $b.EstimatedChargeRemaining
    $acOnline = ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 1)

    if ($acOnline) {
        if ($charge -ge $stopAt) {
            & $ecTool $driver -w $regAddr $inhibitVal | Out-Null
            if (-not $inhibited) {
                $inhibited = $true
                $tray.Icon = $redIcon
                $tray.ShowBalloonTip(3000, "Battery Cap", "Charging stopped at ${charge}%", 2)
            }
        } elseif (-not $inhibited) {
            & $ecTool $driver -w $regAddr $autoVal | Out-Null
            $tray.Icon = $greenIcon
        }
        if ($inhibited) { & $ecTool $driver -w $regAddr $inhibitVal | Out-Null }
    } else {
        $tray.Icon = $grayIcon
        $inhibited = $false
    }
})

$timer.Start()
[System.Windows.Forms.Application]::Run()
