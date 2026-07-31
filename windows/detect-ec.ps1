<#
.SYNOPSIS
    EC Register Discovery Tool — find battery charge control register on any laptop
.DESCRIPTION
    Scans known EC register addresses for battery charge control capability.
    If the standard addresses don't work, allows manual scan of a range.
    Use this if your laptop model is not already supported.
.NOTES
    Known register map:
      HP Pavilion 15-eg3xxx  → 0x76  (0x40 = AUTO, 0x45 = INHIBIT)
      HP EliteBook 8xx G6+   → 0xD7  (0x02 = 80%, varies by model)
      Lenovo IdeaPad          → 0x6A  (0x01 = 80%, 0x03 = 100%)
      ASUS                   → 0x00120068 (ACPI, not direct EC)
      Dell                   → 0x0F  (varies by model)
#>

param(
    [string]$EcTool = "C:\EC-Tool\EC-Access-Tool.exe",
    [switch]$ScanRange,
    [int]$StartAddr = 0x70,
    [int]$EndAddr = 0xFF
)

if (-not (Test-Path $EcTool)) {
    Write-Host "EC-Access-Tool not found at $EcTool" -ForegroundColor Red
    Write-Host "Set path with -EcTool parameter" -ForegroundColor Yellow
    exit 1
}

# Test basic access
$driver = if ((Get-Service RwDrv -ErrorAction SilentlyContinue).Status -eq "Running") { "-rwdrv" } else { "-winring0" }
$test = & $EcTool $driver -r 76 2>$null
if (-not ($test -match "0x")) {
    Write-Host "Driver not responding. Run: setup.bat (or $EcTool -install)" -ForegroundColor Red
    exit 1
}

Write-Host "=== EC Register Discovery ===" -ForegroundColor Cyan
Write-Host ""

<#
  === HOW TO FIND YOUR REGISTER ===
  
  1. Charge battery above 90% with AC plugged in
  2. Note the register value (should show AUTO/charging state)
  3. Run: detect-ec.ps1 -ScanRange
  4. Unplug AC
  5. Run detect-ec.ps1 again and see which register CHANGED
     The register that changes between plugged/discharging may be charge control
  
  6. Alternatively, look for registers with values like 0x00/0x80/0xC5
     or similar patterns when toggling charge state
   
  7. Once found, try writing different values:
     $tool -w <addr> <val>
     Test: 0x00, 0x40, 0x45, 0x80, 0xC5
#>

function Test-KnownRegister($addr, $label) {
    $v = & $EcTool $driver -r $addr 2>$null
    if ($v -match "0x[0-9a-f]+") {
        Write-Host "  0x$("{0:x2}" -f $addr) ($label) : $($v.Trim())" -ForegroundColor Gray
        return $v.Trim()
    }
    return $null
}

Write-Host "Testing known registers:" -ForegroundColor Yellow
Test-KnownRegister 0x76 "BDVO (HP Pavilion)"
Test-KnownRegister 0xD7 "Battery cut (HP EliteBook)"
Test-KnownRegister 0x6A "Lenovo charge limit"
Test-KnownRegister 0x0F "Dell charge control"
Test-KnownRegister 0x69 "Lenovo alternative"
Test-KnownRegister 0x03 "Misc EC"

Write-Host ""
Write-Host "Current battery state:" -ForegroundColor Yellow
$b = Get-WmiObject Win32_Battery -ErrorAction SilentlyContinue
if ($b) {
    $ac = if ($b.BatteryStatus -eq 2) { "Plugged (charging)" } elseif ($b.BatteryStatus -eq 1) { "Not charging" } else { "Discharging" }
    Write-Host "  Charge: $($b.EstimatedChargeRemaining)% | AC: $ac" -ForegroundColor Gray
}

if ($ScanRange) {
    Write-Host ""
    Write-Host "Scanning range 0x$("{0:x2}" -f $StartAddr) - 0x$("{0:x2}" -f $EndAddr)..." -ForegroundColor Yellow
    Write-Host "  (non-zero values shown, press Ctrl+C to stop)" -ForegroundColor DarkGray
    Write-Host ""
    for ($a = $StartAddr; $a -le $EndAddr; $a++) {
        $v = & $EcTool $driver -r $a 2>$null
        if ($v -match "0x[0-9a-f]+" -and $v.Trim() -ne "0x00" -and $v.Trim() -ne "0x80") {
            Write-Host "  0x$("{0:x2}" -f $a) = $($v.Trim())"
        }
    }
    Write-Host ""
    Write-Host "Look for registers that:" -ForegroundColor Cyan
    Write-Host "  1. Change value when you plug/unplug AC"
    Write-Host "  2. Change value at different charge levels (e.g., 60% vs 90%)"
    Write-Host "  3. React when you write test values (careful!)"
} else {
Write-Host ""
Write-Host "To scan full range, run:" -ForegroundColor Cyan
Write-Host "  detect-ec.ps1 -ScanRange" -ForegroundColor White
Write-Host ""
Write-Host "Suggested approach:" -ForegroundColor Yellow
Write-Host "  1. Run detect-ec.ps1 with AC plugged (battery > 90%)"
Write-Host "  2. Run detect-ec.ps1 with AC unplugged"
Write-Host "  3. Compare outputs — registers that changed are interesting"
Write-Host ""
Write-Host "See also:" -ForegroundColor Cyan
Write-Host "  docs/GENERIC_GUIDE.md   — Full walkthrough for any laptop"
Write-Host "  docs/known-registers.md — Community register database"
}
