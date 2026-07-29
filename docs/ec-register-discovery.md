# EC Register Discovery Guide

Every laptop manufacturer uses a different Embedded Controller (EC) register for battery charge control. This guide explains how to find the right register for your specific laptop model.

## Prerequisites

- RW-Everything (Windows) or `ec_sys` kernel module (Linux)
- EC-Access-Tool with WinRing0 driver installed
- AC charger and battery above 50%

## Step 1: Understand the Register Pattern

Battery charge control registers typically:
1. Have a **different value when charging vs not charging**
2. Change when you write specific values
3. Live in the **0x00–0xFF** range (lower 256 EC I/O ports)

Known patterns:
- **AUTO states:** 0x40, 0x00, 0x80, 0x03
- **INHIBIT states:** 0x45, 0x01, 0xC5 (bit 7 is often a status flag)
- **Some registers** are read-only and indicate battery status — look for read-write

## Step 2: Scan with EC-Access-Tool

### Method A: Quick check with known addresses

Run `detect-ec.ps1` which tests common registers:

```powershell
powershell -File windows/detect-ec.ps1
```

### Method B: Full range scan

```powershell
powershell -File windows/detect-ec.ps1 -ScanRange -StartAddr 0x60 -EndAddr 0x90
```

### Method C: Manual RW-Everything

1. Open **RW-Everything** → **Access** → **EC Space**
2. Look at registers 0x00–0xFF
3. Note which values change when you:
   - Plug / unplug AC
   - Battery goes above/below 80%
4. Try writing candidate values and re-reading

## Step 3: The Trial Method

If scanning doesn't immediately reveal the register:

1. **Charge battery to >90%** with AC plugged
2. Read and **note all EC register values** (save to file)
3. **Unplug AC** and let battery discharge to 85%
4. Read and note all values again
5. **Compare** — registers that changed between step 2 and 4 are battery-related
6. For each changed register, try writing different values:
   ```powershell
   EC-Access-Tool -winring0 -w <addr> 00
   EC-Access-Tool -winring0 -w <addr> 40
   EC-Access-Tool -winring0 -w <addr> 45
   EC-Access-Tool -winring0 -w <addr> 80
   EC-Access-Tool -winring0 -w <addr> C5
   ```
7. **Check if charging stops** (watch battery% or WMI `ChargeRate`)

## Step 4: Verify the Register

Once you find a register that stops charging:

1. **Write AUTO value** → confirm charging resumes
2. **Write INHIBIT value** → confirm charging stops
3. **Wait 10–15 seconds** — does the register revert? (volatile firmware check)
4. If volatile, you need the **3-second re-write** approach (like this project)
5. If stable, a single write is sufficient

## Step 5: Update the Daemon

Edit `daemon.ps1` with your discovered values:

```powershell
$regAddr    = "<your hex addr>"   # e.g., "76" for 0x76
$autoVal    = "<AUTO value>"       # e.g., "40"
$inhibitVal = "<INHIBIT value>"    # e.g., "45"
```

## Known Register Map

| Laptop | Register | AUTO | INHIBIT | Notes |
|--------|----------|------|---------|-------|
| HP Pavilion 15-eg3xxx | 0x76 | 0x40 | 0x45 | Volatile — needs 3s re-write |
| HP EliteBook 840 G6+ | 0xD7 | 0x00 | 0x02 | Stable |
| HP EliteBook 845 G8 | 0x69 | 0x00 | 0x01 | May need bit 0 toggle |
| Lenovo IdeaPad 5 | 0x6A | 0x03 | 0x01 | Stable (0x03 = full, 0x01 = 80%) |
| Lenovo ThinkPad | 0x0132 | 0x00 | 0x01 | Via ACPI, not direct EC |
| Dell Latitude 5400 | 0x0F | 0x00 | 0x80 | Read-only on some models |
| ASUS ZenBook | varies | — | — | Uses ACPI, not direct EC |

## Safety Notes

- **Writing to arbitrary EC registers can crash your system** or cause hardware damage
- Only write to registers you've verified are for charge control
- If your laptop freezes after a write, **remove AC + battery** and reboot
- Some manufacturers lock EC registers after boot — may need SMM or ACPI method instead
