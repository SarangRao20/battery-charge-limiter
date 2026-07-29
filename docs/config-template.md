# Configuration Templates

Use these templates to adapt the daemon to any laptop.

## Windows (daemon.ps1 variables)

```powershell
# === YOU NEED TO CHANGE THESE ===
$regAddr    = "76"        # EC register address (hex, WITHOUT 0x prefix)
                          # e.g., "76" for 0x76, "D7" for 0xD7
$autoVal    = "40"        # Value that resumes normal charging
                          # Common: "40", "00", "03"
$inhibitVal = "45"        # Value that stops charging
                          # Common: "45", "01", "80", "02"

# === OPTIONAL — change these if you want ===
$stopAt     = 80           # Target charge limit (%)
$pollSec    = 3            # Seconds between EC writes
                           # 3 for volatile, 60 for stable registers
$ecTool     = "C:\EC-Tool\EC-Access-Tool.exe"
$driver     = "-winring0"  # or "-rwdrv" for RwDrv.sys
```

## Arch Linux (config file)

File: `/etc/battery-charge-limiter.conf`

```ini
# === Battery Charge Limiter Configuration ===

# Battery thresholds (percentage)
START_THRESHOLD=75    # Resume charging when battery drops to this %
STOP_THRESHOLD=80     # Stop charging when battery reaches this %

# Check interval (seconds)
POLL_INTERVAL=60      # How often to check battery level
                       # 60 for stable registers, 3-5 for volatile
```

If the ACPI methods are different from HP's, edit:
`/usr/local/bin/battery-charge-limiter` — change `WMI_INHIBIT` and `WMI_AUTO`.

---

## How to Pick Your Values

| You have... | Use this |
|-------------|----------|
| A register that resets in <10s | `pollSec = 3` (Windows) / `POLL_INTERVAL = 3` (Arch via code edit) |
| A register that stays put | `pollSec = 60` / `POLL_INTERVAL = 60` |
| ACPI method access (no direct register) | Use Arch daemon approach — edit the WMI strings |
| Only Windows tools available | Start with Windows daemon, migrate to Arch later |
