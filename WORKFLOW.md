# Battery Charge Limiter — Workflow

## The Problem
HP Pavilion 15-eg3xxx has no BIOS-level battery charge limit (unlike EliteBook/ProBook). After 2 years of always-plugged use at 100%, battery degraded to 71% health (41,050 mWh → 29,234 mWh, 240 cycles). Consumer HP laptops lack Battery Health Manager.

## Approach
Instead of relying on missing firmware features, bypass the BIOS entirely by writing directly to the Embedded Controller (EC) register that controls battery charging.

## Discovery Phase

### 1. Check Built-in Options
- **myHP app** → No Battery Health Manager
- **HP Command Center** → No charge limit setting
- **BIOS (F.05)** → Only "Adaptive Battery Extender" (smart learning, NOT strict 80% limit)
- **HP WMI** (`root\hp\instrumentedbios`) → No charge limit variable exposed

### 2. Find EC Register
- Download **EC-Access-Tool.exe** + **WinRing0x64.sys**
- Install WinRing0 driver
- Scan EC registers while plugging/unplugging AC
- Identify register **0x76** (BDVO — Battery De-Voltage Optimizer)
- Values:

| Value | Behavior | LED |
|-------|----------|-----|
| `0x00` | Stock — charges normally | RED |
| `0x40` | AUTO (similar to stock) | WHITE (~1s) → flickers back to RED (0x00) |
| `0x45` | **Stops charging**, AC stays online | RED |
| `0x42` | Stops charging but disconnects AC | WHITE (battery drains) |

**Key insight:** 0x40 gets reset by EC firmware to 0x00 within 1-2s → flicker. But both 0x00 and 0x45 are stable.

### 3. Read-back Behavior
- Writing `0x00` → reads back as `0x80` (bit 7 status flag)
- Writing `0x45` → reads back as `0xC5` (original bit 7 flag preserved)

### 4. Final Values
| Mode | Write Value | Read-back | Effect |
|------|-----------|-----------|--------|
| AUTO (charge ≤80%) | `0x00` | `0x80` | Stock behavior, RED LED |
| INHIBIT (charge >80%) | `0x45` | `0xC5` | Stop charge, RED LED, AC stays on |

## Solution Architecture

### Daemon (`windows/daemon.ps1`)
- Language: PowerShell -STA (required for Windows.Forms NotifyIcon)
- Poll: Every **3 seconds** (EC firmware resets register — must re-write)
- Detection: WMI `Win32_Battery` for charge %, `PowerLineStatus` for AC (NOT WMI Charging flag — false negative when inhibited)
- Hysteresis: Once inhibited, stays inhibited until charger unplugged

### Icon States
| Icon | Condition | EC Value |
|------|-----------|----------|
| 🟢 Green | Charge <80% AND AC plugged | Write `0x00` (AUTO) |
| 🔴 Red | Charge ≥80% AND AC plugged | Write `0x45` (INHIBIT) |
| ⚫ Gray | AC unplugged (discharging) | Do nothing |

### Tray Menu
- **Check Status** → Shows live battery %, EC read-back, charge state
- **Bypass — Full Charge** → Writes 0x00 to let battery charge past 80% once
- **Exit** → Stops daemon (EC falls back to stock behavior)

### Single Instance Mutex
Prevents duplicate daemons. No PID file, no logging, no registry writes.

## Setup Process

### Installer (`windows/setup.ps1`)
1. Install WinRing0 driver (AUTO_START)
2. Copy daemon.ps1 + icons → C:\EC-Tool\
3. Create scheduled task **Battery80Cap** (AtLogon trigger)
4. Start daemon immediately

### Manual Steps (first time)
1. Disable Secure Boot (required for unsigned WinRing0 driver)
2. Add Windows Defender exclusion for C:\EC-Tool\
3. Run setup.ps1 as Administrator

## Testing & Verification

### EC Read/Write Test
```powershell
# Read current value
& "C:\EC-Tool\EC-Access-Tool.exe" /ro 0x76

# Write inhibit
& "C:\EC-Tool\EC-Access-Tool.exe" /wo 0x76 0x45

# Write auto
& "C:\EC-Tool\EC-Access-Tool.exe" /wo 0x76 0x00
```

### Verify Charge Stops
- At 80%+: Charge rate drops to 0 in WMI, RED tray icon appears
- Unplug/replug: Charge resumes (0x00), RED icon, daemon re-detects <80%
- Below 80%: Normal charging, GREEN icon

## Files

```
ec-charge-hack/
├── WORKFLOW.md                           ← This file
├── README.md
├── windows/
│   ├── daemon.ps1            # Main tray daemon
│   ├── setup.ps1             # One-click installer
│   ├── detect-ec.ps1         # EC register scanner
│   ├── GUIDE.md              # Step-by-step tutorial
│   └── icons/
│       ├── green.ico         # Charging (<80%)
│       ├── red.ico           # Inhibited (≥80%)
│       └── gray.ico          # Discharging
├── arch/                     # Linux implementation
├── docs/
│   ├── ec-register-discovery.md
│   └── screenshots/
│       ├── 01-terminal-proof.png
│       ├── 02-tray-icons.png
│       ├── 03-tray-green.png
│       └── 04-tray-red.png
```

## Why This Approach Works

| Problem | Solution |
|---------|----------|
| No BIOS charge limit | Bypass BIOS, write to EC directly |
| EC firmware resets register | Re-write every 3 seconds |
| WMI shows Charging=False when inhibited | Use `PowerLineStatus` for AC detection |
| Dual daemon instances | Global mutex |
| Tray icon needs GUI thread | PowerShell -STA flag |
| Consumer HP hides the feature | Hidden EC register still works |
