# Arch Linux Setup Guide : The "I Don't Want My Battery To Die In 2 Years" Edition (Linux Edition)

Same problem, different OS. Your HP Pavilion is plugged in 24/7, battery health is dropping, and HP decided consumer laptops don't deserve a charge limit feature. Let's fix that the Linux way.

---

## Wait, Does This Work On My Laptop?

**Probably not out of the box** — unless you have an HP Pavilion 15-eg3xxx.

This project uses **ACPI WMI methods** specific to HP Pavilion 15-eg3xxx:
- `\_SB.WMID.SBCO` → Inhibit charge
- `\_SB.WMID.SBCC` → Auto charge (normal)

On other laptops, the ACPI namespace paths will be different. But the approach is the same:
1. Find the right ACPI method
2. Write a daemon that calls it at the right threshold

If you have a different laptop, start with `detect-ec.sh` to explore what's available.

---

## Step 0: Prerequisites

- **Arch Linux** (or any Linux with `acpi_call` support)
- **acpi_call-dkms** kernel module (required to write ACPI methods)
- **Root access** (the daemon needs to write to `/proc/acpi/call`)

---

## Step 1: Install acpi_call

The daemon talks to the EC through ACPI methods — it needs the `acpi_call` kernel module:

```bash
# From official repos (if available)
sudo pacman -S acpi_call-dkms

# OR from AUR
yay -S acpi_call-dkms
# paru -S acpi_call-dkms
```

Load the module:

```bash
sudo modprobe acpi_call
```

Make it persistent across reboots:

```bash
echo "acpi_call" | sudo tee /etc/modules-load.d/acpi_call.conf
```

Verify it works:

```bash
# This should show the file exists
ls -l /proc/acpi/call
```

---

## Step 2: Quick Test

Before running the daemon, test that your EC actually responds to the ACPI methods.

**With charger plugged in** (AC adapter connected):

```bash
# Read current battery status
cat /sys/class/power_supply/BAT0/status
cat /sys/class/power_supply/BAT0/capacity

# INHIBIT — stop charging (should work immediately)
echo '\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}' | sudo tee /proc/acpi/call
cat /proc/acpi/call

# Check: if charging stopped, power_now should drop to 0
watch -n 1 'cat /sys/class/power_supply/BAT0/power_now'
```

**To resume charging:**

```bash
echo '\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}' | sudo tee /proc/acpi/call
cat /proc/acpi/call
```

Expected output from `cat /proc/acpi/call`:
- After inhibit: `0x{}` (empty buffer — HP returns this on success)
- After auto: `0x{}` (same — success is empty)

---

## Step 3: Run the Daemon

### Option A: AUR (recommended)

```bash
yay -S battery-charge-limiter
# or: paru -S battery-charge-limiter
```

Then enable the service:
```bash
sudo systemctl enable --now battery-charge-limiter
```

### Option B: One-click installer

```bash
cd arch/
sudo bash setup.sh
```

This handles everything: installs dependencies, loads modules, sets up the service, creates aliases.

### Option C: Manual

```bash
# Copy the daemon
sudo cp arch/battery-charge-limiter /usr/local/bin/
sudo chmod +x /usr/local/bin/battery-charge-limiter

# Copy the service file
sudo cp arch/battery-charge-limiter.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now battery-charge-limiter
```

Check if it's running:

```bash
systemctl status battery-charge-limiter
journalctl -u battery-charge-limiter -f
```

---

## Step 4: Helper Aliases

If you used `setup.sh`, the aliases are already installed. Otherwise, add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Battery Charge Limiter aliases
alias bat-inhibit='echo "\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}" | sudo tee /proc/acpi/call && echo "Charging INHIBITED"'
alias bat-auto='echo "\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}" | sudo tee /proc/acpi/call && echo "Charging AUTO restored"'
alias bat-status='echo "Battery:" && cat /sys/class/power_supply/BAT0/capacity | xargs -I{} echo "  Level: {}%" && cat /sys/class/power_supply/BAT0/status | xargs -I{} echo "  Status: {}" && cat /sys/class/power_supply/BAT0/power_now | awk "{printf \"  Power: %.2f W\\n\", \$1/1000000}"'
```

Then `source ~/.bashrc` and you're good.

---

## What Should Happen

1. **Battery below 80%, AC plugged** → daemon does nothing (charging is fine)
2. **Battery hits 80%, AC plugged** → daemon calls `SBCO` → charging stops → `power_now = 0`
3. **Battery drains to 75% (still plugged)** → daemon calls `SBCC` → charging resumes
4. **AC unplugged** → `status = Discharging` → daemon waits
5. **AC re-plugged** → daemon evaluates: if ≥80%, inhibit; if ≤75%, resume

### Edge Cases

- **No battery detected** (desktop): daemon reads `None` and spins harmlessly — no crash
- **acpi_call module not loaded**: daemon exits with clear error message
- **Battery removed**: `/sys/class/power_supply/BAT0/` disappears — daemon handles gracefully

---

## How It's Different From Windows

| Aspect | Windows | Arch Linux |
|--------|---------|------------|
| EC access method | RW-Everything / WinRing0 (EC register direct) | acpi_call (ACPI WMI method) |
| Register | 0x76 (BDVO) direct write | `\_SB.WMID.SBCO/SBCC` ACPI methods |
| Re-write frequency | Every 3 seconds | Every 60 seconds |
| Why? | EC firmware resets register | ACPI method sets a state — less volatile |
| Driver needed | WinRing0x64.sys (signed) | acpi_call-dkms (kernel module) |
| Tray icon | Yes (PowerShell NotifyIcon) | No (headless service) |

**Why is Linux simpler?** The ACPI WMI method sets a persistent state in the EC that doesn't reset as aggressively as the raw register write. So 60-second polling is enough — no need for a 3-second hammer loop.

---

## Customization

Edit `/usr/local/bin/battery-charge-limiter`:

```python
START_THRESHOLD = 75   # Resume charging at this %
STOP_THRESHOLD  = 80   # Stop charging at this %
POLL_INTERVAL   = 60   # Check every N seconds
```

Then restart:

```bash
sudo systemctl restart battery-charge-limiter
```

Same script, different hardware? Update the ACPI method strings:

```python
WMI_INHIBIT = r"\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}"
WMI_AUTO    = r"\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}"
```

---

## Troubleshooting

### "acpi_call module not found"
```bash
# Check available kernels
ls /usr/lib/modules/
# Rebuild dkms
sudo dkms install -m acpi_call -v <version>
```

### "Permission denied" on /proc/acpi/call
Run the daemon as root (it does this automatically via systemd). Manual commands need `sudo`.

### "Daemon running but battery still charging past 80%"
Check the logs:
```bash
journalctl -u battery-charge-limiter -n 50
```
Likely reasons:
- Wrong ACPI method paths
- EC doesn't support charge inhibit on your model
- Battery not actually detected (shows `None`)

### "Battery at 0% on desktop"
That means there's no battery — `/sys/class/power_supply/BAT0/` doesn't exist or has no capacity. The daemon handles this gracefully.

### "Charging LED went white at 80%"
That's normal. The white LED on HP means "charging complete" — and at the hardware level, inhibit = complete as far as the EC knows.

### "How do I temporarily disable the limiter?"
```bash
sudo systemctl stop battery-charge-limiter
sudo systemctl disable battery-charge-limiter  # permanent
```

---

## Final Notes

This daemon has been running on my HP Pavilion 15-eg3xxx for weeks. Battery sits at 80% all day. No issues. Same fix, different OS.

If you found this useful, star the repo. If something breaks, open an issue.
