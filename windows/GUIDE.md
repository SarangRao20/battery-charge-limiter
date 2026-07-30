# Windows Setup Guide : The "I Don't Want My Battery To Die In 2 Years" Edition

So you've got a laptop that stays plugged in 24/7, and you're tired of watching your battery health go from 100% to 71% in two years (yes, that's what happened to me — 240 charge cycles later, ouch). Let's fix that.

---

## Wait, Does This Work On My Laptop?

Short answer: **Probably not out of the box.**

This project specifically targets the **HP Pavilion 15-eg3xxx** with EC register **0x76** using values **0x40** (AUTO) and **0x45** (INHIBIT).

If you have a different laptop, you'll need to:
1. Find your EC register first — run `detect-ec.ps1` or check [docs/ec-register-discovery.md](../docs/ec-register-discovery.md)
2. Update `daemon.ps1` with your register address and values

If your laptop is from HP, Lenovo, Dell, or ASUS — there's a good chance it has a charge control register somewhere. Just gotta find it.

---

## Step 0: Prerequisites

- **Windows 10 or 11**
- **Admin access** (you'll need to install a driver)
- **Secure Boot disabled** (or the driver won't load — Google how to disable it for your laptop model)
- **The daemon script** — whatever, you're here on GitHub, you have it

---

## Step 1: Download EC-Access-Tool

This is the tool that talks to your Embedded Controller. It supports **two drivers**:

- **RwDrv.sys** — from RW-Everything, **Microsoft-signed** (works with Secure Boot ON) ✅ recommended
- **WinRing0x64.sys** — works on most systems (may need Secure Boot disabled)

**A note on safety:** Both drivers are standard, widely-used components. WinRing0 is the same driver used by CrystalDiskMark and Open Hardware Monitor. A community member on Reddit (`port443`) independently reversed the driver in Ghidra and confirmed it's a straightforward I/O access driver — no malicious functionality. The installer also verifies SHA256 hashes automatically.

Download from here:  
👉 [https://github.com/shubhampaul/EC-Access-Tool](https://github.com/shubhampaul/EC-Access-Tool)

Or just run `setup.ps1` which downloads everything and verifies hashes.

---

## Step 2: Install the Driver

The tool supports two drivers. Pick one:

### Option A: WinRing0 (simpler, may need Secure Boot disabled)

```powershell
C:\EC-Tool\EC-Access-Tool.exe -install
```

Expected output:
```
WinRing0 Install ... SUCCESS
WinRing0 Start ... SUCCESS
```

If it fails:
- **Secure Boot** is enabled → try Option B (RwDrv) instead, or disable Secure Boot in BIOS
- **Windows Defender** is blocking it → add exclusion for `C:\EC-Tool\`

### Option B: RwDrv (Microsoft-signed, works with Secure Boot ON)

Copy `RwDrv.sys` from a RW-Everything installation (`C:\Windows\System32\drivers\RwDrv.sys`) to `C:\EC-Tool\`, or [download RW-Everything](https://www.rweverything.com/) and extract it.

Then start the driver service:

```powershell
sc create RwDrv type= kernel binPath= "C:\EC-Tool\RwDrv.sys"
sc start RwDrv
```

### Verify

```powershell
C:\EC-Tool\EC-Access-Tool.exe -winring0 -r 76
```

Or with RwDrv:

```powershell
C:\EC-Tool\EC-Access-Tool.exe -rwdrv -r 76
```

If you get a hex value like `0x80` or `0x00`, you're good.

---

## Step 3: Test EC Access

Before running the daemon, make sure the register actually does something.

**With charger plugged in:**

```powershell
# Read current value
C:\EC-Tool\EC-Access-Tool.exe -winring0 -r 76

# Write inhibit value
C:\EC-Tool\EC-Access-Tool.exe -winring0 -w 76 45

# Read again to confirm
C:\EC-Tool\EC-Access-Tool.exe -winring0 -r 76

# Check if charging actually stopped
Get-WmiObject -Namespace "root\wmi" -Class BatteryStatus
```

What to expect:
- Before: `0x80` (AUTO — charging allowed)
- After write: `0x45` (raw), reads back as `0xC5` (INHIBITED)
- `Charging=False` and `ChargeRate=0` in WMI output

**To resume charging:**

```powershell
C:\EC-Tool\EC-Access-Tool.exe -winring0 -w 76 40
```

Expected: reads back as `0x80` (AUTO), charging resumes.

---

## Step 4: Run the Daemon

The daemon (`daemon.ps1`) is a system tray app that:
- Monitors battery level every 3 seconds
- Automatically inhibits charging at 80%
- Shows colored icons: 🟢 GREEN (charging) / 🔴 RED (inhibited) / ⚫ GRAY (discharging)
- Handles the EC firmware reset problem (more on that below)

Run it:

```powershell
powershell -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File daemon.ps1
```

**That `-STA` flag is IMPORTANT.** Without it, the tray icon won't appear. No error message either — it just silently refuses. Fun.

If it worked, you'll see a **green circle** appear in your system tray. If you don't see it, check the overflow area (the little arrow `^`).

---

## Step 5: Set It to Run Automatically

Don't want to remember to launch this every time you reboot? Good news.

### Option A: Use the setup script (recommended)

```powershell
# Run as Administrator
powershell -ExecutionPolicy Bypass -File windows\setup.ps1
```

This creates a scheduled task called **Battery80Cap** that runs at startup (30-second delay) and on logon. Hidden window, highest privileges, all that jazz.

### Option B: Do it yourself

Create a scheduled task manually in Task Scheduler:
- **Trigger:** At startup + At logon
- **Action:** Start a program → `powershell.exe`
- **Arguments:** `-STA -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\EC-Tool\daemon.ps1`
- **Run with highest privileges**

---

## What Should Happen (The Lifecycle)

1. **Plug in charger** → battery starts charging
2. **Battery is below 80%** → 🟢 **Green icon**, charging normally
3. **Battery hits 80%** → 🔴 **Red icon**, daemon writes inhibit, charging stops, popup notification
4. **Unplug charger** → ⚫ **Gray icon**, battery discharges naturally
5. **Plug charger back in**:
   - If battery is below 80% → 🟢 **Green**, resumes charging, stops at 80% again
   - If battery is still above 80% → 🔴 **Red**, immediately stops (no point charging to go higher)

---

## The EC Firmware Reset "Feature"

Here's the funny part: the HP Pavilion's EC firmware **doesn't like staying inhibited.**

You write `0x45`, charging stops — great. Then 5 seconds later, the EC firmware goes "lol no" and resets the register back to `0x80` (AUTO). Charging resumes.

That's why the daemon **re-writes the inhibit value every 3 seconds.** It's not paranoia — it's firmware being annoying.

Without the daemon running, a single inhibit write only lasts a few seconds. With the daemon, it stays inhibited indefinitely.

---

## Troubleshooting

### "The tray icon doesn't show!"
- Forgot `-STA` flag. Run with it.
- Already running? The daemon has a **single-instance mutex** — only one copy runs at a time. Check the existing one first.

### "WinRing0 won't install!"
- Secure Boot is on → disable in BIOS
- Windows Defender → add exclusion
- Try running the `.exe` directly from `C:\EC-Tool\` (not from Downloads or Desktop)

### "I ran the daemon but nothing happens"
- Check if the process is running: `Get-Process -Name powershell`
- Check the register: `EC-Access-Tool -r 76` — should show `0xC5` if inhibited
- Check battery: `Get-WmiObject Win32_Battery` — status should be 2 (plugged)

### "My battery is still charging past 80%!"
- Daemon probably isn't running
- Or your register address/values are wrong
- Or the EC doesn't support charge control on your model

### "77% pe charge kyu nahi ho raha?"
Check the register: `EC-Access-Tool -r 76`
- If it shows `0xC5` → daemon thinks inhibited. But why? If you just unplugged and re-plugged, the daemon should detect charging and resume
- Try literally unplugging and plugging the charger again
- Or toggle bypass from the tray menu: right-click → "Bypass — Full Charge" → then "Cancel Bypass"

---

## Behavior Reference — Kab Chalta Hai, Kab Nahi

### Scenario Table

| Situation | Icon | Charging? | Daemon Action |
|-----------|------|-----------|---------------|
| Charger plugged, battery < 80% (not inhibited) | 🟢 Green | ✅ Yes | Writes AUTO (0x40) every 3s |
| Charger plugged, battery = 80% | 🔴 Red | ❌ Stopped | Writes INHIBIT (0x45) every 3s |
| Charger plugged, battery > 80% | 🔴 Red | ❌ Stays stopped | Keeps writing INHIBIT |
| Battery dropping from 80% → 75% (still plugged) | 🔴 Red | ❌ **Still stopped** | INHIBIT remains — **does NOT resume until unplugged** |
| Charger unplugged at any % | ⚫ Gray | ❌ Discharging | Resets inhibited flag, lets battery drain |
| Plug charger back in at 75% | 🟢 Green | ✅ Resumes | Fresh cycle — charges until 80% |
| Plug charger back in at 82% | 🔴 Red | ❌ Stops immediately | Inhibits right away
| Reboot — daemon not yet started | None | ✅ Charges freely | No daemon = no protection |
| ~30s after reboot | Icon appears | Varies | Daemon starts, reads battery, acts accordingly |
| Daemon crashes / killed | Icon disappears | ✅ Charges freely | Protection lost until restarted |
| Bypass enabled (right-click menu) | 🟢 Green | ✅ Charges to 100% | Daemon hands off, does nothing |
| Bypass cancelled | 🟢/🔴 | Varies | Daemon resumes control |

### What Does NOT Happen

- The daemon does **not** discharge your battery. It only **stops charging**.
- The daemon does **not** control how fast you discharge. That's your hardware.
- The daemon does **not** turn off your laptop or put it to sleep.
- The daemon does **not** work without WinRing0 driver installed and running.
- The daemon does **not** protect you if it's not running (check tray icon!).

### The Weird Edge Cases

**"I plugged charger at 79% but it's not charging — icon is gray!"**

Check if the daemon is actually running. If the tray icon is missing, the daemon isn't there. Start it.

**"I plugged charger at 83% and it went red — but battery is dropping to 82, 81... that's fine right?"**

Yes. Correct behavior. Charging is inhibited, battery is just naturally discharging. Since it's still above 80%, the daemon keeps it inhibited. Once it drops below 80%, it **stays inhibited** until you unplug and replug the charger. That's by design — prevents LED flicker.

**"I need it to charge back up!"**

Unplug the charger for 2 seconds, plug it back in. The daemon resets on unplug, so it'll start a fresh charge cycle.

**"What if I want it to charge to 100% for a trip?"**

Right-click the tray icon → **"Bypass — Full Charge"**. It'll turn green and let it charge all the way. When you're back, right-click again → "Cancel Bypass".

**"What happens if I edit the script while it's running?"**

Nothing — the running process has the old code in memory. Stop and restart the daemon to pick up changes.

**"Will this work if my laptop is in sleep mode?"**

Sleep mode keeps the EC running, and the register state persists. But the daemon (running in Windows) is paused during sleep. When you wake the laptop, the daemon resumes, reads the battery, and acts accordingly. There's a ~3 second window where the EC firmware might reset the register before the daemon re-writes — but that usually just means one extra blip of charging before it's caught.

---

## Customizing

Wanna change 80% to 85%? Edit `daemon.ps1`:

```powershell
$stopAt = 85    # new limit
```

Don't forget to restart the daemon after editing.

Different laptop? Different register? Same script, just change:

```powershell
$regAddr    = "D7"    # your register in hex
$autoVal    = "00"    # your AUTO value
$inhibitVal = "02"    # your INHIBIT value
```

---

## Final Notes

This isn't a polished commercial product — it's a "I'm annoyed my laptop doesn't have this feature" project that got way more involved than expected. But it works. My battery's been sitting at 80% for days now, and that's exactly what I wanted.

If something breaks, well — that's what `Exit` button in the tray menu is for.
