# I Have A Different Laptop — What Do I Do?

This project targets **HP Pavilion 15-eg3xxx** out of the box. But the same approach works on any laptop — you just need to find your own EC register.

---

## The Universal Workflow

```
1. DETECT   → Find which EC register controls charging on YOUR laptop
2. TEST     → Verify writing to that register actually stops/resumes charge
3. CONFIGURE → Update the daemon config with your register address + values
4. DEPLOY   → Run the daemon, let it auto-manage
```

---

## Step 1: Detection

### On Windows (easier)

Use `detect-ec.ps1`:

```powershell
# Quick check: test known registers
.\windows\detect-ec.ps1

# Full scan: dump all non-zero registers
.\windows\detect-ec.ps1 -ScanRange -StartAddr 0x00 -EndAddr 0xFF
```

**What to look for:**

Run the scan **twice** — once with AC plugged (battery > 80%), once with AC unplugged. Compare outputs. Registers that changed value are battery-related.

Example:
```
AC plugged:  0x76 = 0x80
AC unplugged: 0x76 = 0x40
```
Register 0x76 changed → it's involved in power/battery control.

### On Linux

```bash
# Load ec_sys module
sudo modprobe ec_sys

# Dump EC register space
sudo xxd /sys/kernel/debug/ec/ec0/io > /tmp/ec_charging

# Unplug AC, wait 10s
sudo xxd /sys/kernel/debug/ec/ec0/io > /tmp/ec_discharging

# Compare
diff /tmp/ec_charging /tmp/ec_discharging
```

Or use the detection script:
```bash
sudo bash arch/detect-ec.sh
```

### Manual Method (both platforms)

Open RW-Everything (Windows) → **EC Space** tab. Scroll through registers 0x00–0xFF and look for:

| What to look for | Why |
|-----------------|-----|
| Value changes when AC plugged/unplugged | Power-related register |
| Value changes at different battery % | Charge-level register |
| Value is something like 0x00, 0x40, 0x80 | Common AUTO/IDLE states |
| Writing to it changes charge behavior | THE ONE |

---

## Step 2: Test Candidate Registers

**⚠️ WARNING:** Writing to random EC registers CAN freeze your laptop or cause hardware issues. Only try registers that showed clear battery-related patterns in Step 1.

For each candidate register, try these test values:

```powershell
# Write candidate value
EC-Access-Tool -winring0 -w <REGISTER> <VALUE>

# Check if charging stopped
Get-WmiObject -Namespace root\wmi -Class BatteryStatus
```

Common value patterns to try:

| Pattern | What it might be |
|---------|------------------|
| `0x00` / `0x01` | On/Off toggle |
| `0x00` / `0x40` / `0x80` | Mode select (AUTO = one of these) |
| `0x45` / `0xC5` | HP-style INHIBIT |
| `0x01` / `0x03` | Lenovo-style (80% vs 100%) |
| `0x00` / `0x02` | EliteBook-style |

**Pro tip:** If you find a register that stops charging when you write X, try writing X again after 10 seconds. If the value reverted — the EC firmware is volatile and you'll need a fast poll interval (3-5 seconds). If it stuck — you can use 60-second polling.

---

## Step 3: Configure the Daemon

### Windows

Edit `windows/daemon.ps1`:

```powershell
$regAddr    = "76"        # ← YOUR register address (hex, without 0x)
$autoVal    = "40"        # ← YOUR AUTO value (resumes charging)
$inhibitVal = "45"        # ← YOUR INHIBIT value (stops charging)
$stopAt     = 80           # Change limit if you want
```

### Arch Linux

Edit `/etc/battery-charge-limiter.conf` after installation:

```ini
START_THRESHOLD=75          # Resume charging at this %
STOP_THRESHOLD=80           # Stop charging at this %
POLL_INTERVAL=60            # Seconds between checks
```

If the ACPI method names differ (they will on non-HP laptops), edit the daemon:

```bash
sudo nano /usr/local/bin/battery-charge-limiter
```

Change the WMI method strings:

```python
WMI_INHIBIT = r"\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}"
WMI_AUTO    = r"\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}"
```

---

## Step 4: Deploy

### Windows

Same as standard setup:
```powershell
.\windows\setup.ps1
```

### Arch Linux
```bash
sudo bash arch/setup.sh
```

---

## Step 5: Contribute Back

Found a register that works on your laptop? Open a PR to update [known-registers.md](known-registers.md) so others don't have to repeat your work.

### What to include:
- Laptop model + BIOS version
- EC register address
- AUTO and INHIBIT values (and any other modes you found)
- Whether it's volatile (resets) or stable
- Platform tested (Windows, Linux, or both)

---

## If You're Stuck

- **The register might not exist** — some laptops genuinely don't have charge control in EC
- **It might be ACPI-only** — look for WMI methods with "BAT", "CHG", "CHARGE" in the DSDT
- **It might be locked** — some manufacturers lock EC after boot to prevent tampering
- **Ask in Issues** — someone might have the same model
