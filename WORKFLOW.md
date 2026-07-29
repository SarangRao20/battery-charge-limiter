# Battery Charge Limiter — Workflow

## The Problem
HP Pavilion 15-eg3xxx has no BIOS-level battery charge limit. After 2 years of always-plugged use at 100%, battery degraded to 71% health (41,050 mWh → 29,234 mWh, 240 cycles).

## Solution
Bypass the BIOS entirely — write directly to the Embedded Controller (EC) register that controls charging.

## Implementation

| Platform | Approach | Details |
|----------|----------|---------|
| **Windows** | Direct EC register write via WinRing0 | [windows/GUIDE.md](windows/GUIDE.md) |
| **Arch Linux** | ACPI WMI method via acpi_call | [arch/GUIDE.md](arch/GUIDE.md) |

Both target the same register: **BDVO @ 0x76** with **AUTO=0x40, INHIBIT=0x45**.

## Repository

```
ec-charge-hack/
├── WORKFLOW.md                        ← This file
├── README.md
│
├── windows/                           # Windows daemon (tray icon, 3s poll)
│   ├── daemon.ps1
│   ├── setup.ps1
│   ├── detect-ec.ps1
│   ├── GUIDE.md
│   └── icons/
│
├── arch/                              # Arch Linux daemon (headless, 60s poll)
│   ├── battery-charge-limiter
│   ├── battery-charge-limiter.service
│   ├── setup.sh
│   ├── detect-ec.sh
│   └── GUIDE.md
│
└── docs/
    ├── ec-register-discovery.md
    └── screenshots/
```

## Key Differences Between Platforms

| Aspect | Windows | Arch Linux |
|--------|---------|------------|
| EC access method | RW-Everything / WinRing0 → direct EC I/O port | acpi_call kernel module → /proc/acpi/call |
| What gets written | Raw value `0x45` to register `0x76` | ACPI buffer → internally writes `0x45` to same register |
| Poll interval | 3 seconds (register resets by firmware) | 60 seconds (ACPI state is more stable) |
| Reason | Direct register write gets overridden by EC firmware | ACPI methods set a persistent state |
| Driver needed | WinRing0x64.sys (or RwDrv.sys) | acpi_call-dkms (kernel module) |
| User interface | System tray icon with colored states | systemd service, journalctl logs |
| Tray icons | 🟢 Green (charging), 🔴 Red (inhibited), ⚫ Gray (discharging) | N/A |

## Why 3s vs 60s?

On Windows, writing `0x45` to register `0x76` stops charging, but the EC firmware resets it back to AUTO (`0x80`) within seconds. The daemon must **continuously re-write** every 3 seconds.

On Linux, the ACPI WMI method (`\_SB.WMID.SBCO` / `\_SB.WMID.SBCC`) sets a state that the firmware respects without aggressive resetting. 60-second polling is enough — the daemon is checking if conditions changed, not fighting a reset.

## Files

See platform-specific guides for detailed file explanations:
- [windows/GUIDE.md](windows/GUIDE.md)
- [arch/GUIDE.md](arch/GUIDE.md)
