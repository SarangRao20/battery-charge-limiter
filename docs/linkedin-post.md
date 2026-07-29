🚀 I reverse-engineered my HP laptop's Embedded Controller to add a hidden feature HP didn't give us

My HP Pavilion 15-eg3xxx has been plugged in 24/7 for 2 years. Result? Battery health dropped to 71% — 41,050 mWh → 29,234 mWh in just 240 cycles.

HP reserves "Battery Health Manager" (80% charge limit) for premium EliteBooks. Consumer Pavilion models? Not a chance.

So I did what any annoyed engineer would do — I fixed it myself.

THE HARD WAY:
1. Dumped and decompiled the DSDT (130,000+ lines of ACPI tables)
2. Mapped out the Embedded Controller register space
3. Found BDVO at register 0x76 — the hidden charge control register
4. Discovered: 0x45 = INHIBIT (stops charging), 0x40 = AUTO (resumes)

TWIST 1: The EC firmware resets the register every few seconds. Can't just write once — need a daemon re-writing every 3 seconds on Windows, 60 seconds on Linux (ACPI path is more stable).

TWIST 2: Sometimes the hardware works, but the OS/driver path doesn't. On Windows, I went through WinRing0 → EC-Access-Tool → Embedded Controller. On Arch Linux, I used acpi_call → ACPI WMI methods. Both paths hit the same EC register.

End result: A cross-platform daemon (Windows + Arch Linux) that enforces 80% hardware-level charge cap, regardless of what the BIOS says.

Open-sourced the entire thing — full reverse engineering docs, EC register discovery tools, and daemon source:

https://github.com/SarangRao20/ec-charge-hack

Tech stack: Python, PowerShell, ACPI/WMI, Embedded Controller firmware, WinRing0, systemd.

No BIOS mod. No HP utility. Just pure EC-level control via the register that was there all along.

What's a hack you've done because the manufacturer wouldn't give you a simple toggle?
