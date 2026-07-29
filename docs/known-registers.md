# Known EC Registers for Battery Charge Control

> Community-maintained database. Found a register on your laptop? Submit a PR!

## HP

| Model | Register | AUTO | INHIBIT | Notes | Source |
|-------|----------|------|---------|-------|--------|
| Pavilion 15-eg3xxx | 0x76 | 0x40 | 0x45 | Volatile (resets in seconds) | Confirmed |
| EliteBook 840 G6+ | 0xD7 | 0x00 | 0x02 | Stable | Report |
| EliteBook 845 G8 | 0x69 | 0x00 | 0x01 | May need bit 0 toggle | Report |
| ProBook 450 G8 | 0xD7 | 0x00 | 0x02 | Same as EliteBook 840 | Report |
| Spectre x360 14 | 0xD7 | 0x00 | 0x02 | Same family | Report |

## Lenovo

| Model | Register | AUTO | INHIBIT | Notes | Source |
|-------|----------|------|---------|-------|--------|
| IdeaPad 5 15ITL05 | 0x6A | 0x03 | 0x01 | 0x03 = full, 0x01 = 60% | Confirmed |
| IdeaPad 5 Pro | 0x6A | 0x03 | 0x01 | Same | Report |
| ThinkPad T14 Gen 2 | 0x0132 | 0x00 | 0x01 | Via ACPI, not direct EC | Report |
| ThinkPad X1 Carbon Gen 9 | — | — | — | Uses ACPI method `BCTG` | Report |

## Dell

| Model | Register | AUTO | INHIBIT | Notes | Source |
|-------|----------|------|---------|-------|--------|
| Latitude 5400 | 0x0F | 0x00 | 0x80 | Read-only on some models | Report |
| Latitude 5420 | 0x0F | 0x00 | 0x80 | Same | Report |
| XPS 15 9500 | 0x0F | 0x00 | 0x80 | May need SMM call | Report |

## ASUS

ASUS typically uses ACPI methods rather than direct EC registers. Check DSDT for `BAT0`, `BATS`, `CHG` methods.

| Model | Method | Notes | Source |
|-------|--------|-------|--------|
| ZenBook UX425 | ACPI | Uses `\_SB.ATKD.BATG` | Report |
| ROG Zephyrus G14 | ACPI | Uses WMI method | Report |

## Acer

| Model | Register | AUTO | INHIBIT | Notes | Source |
|-------|----------|------|---------|-------|--------|
| Predator Helios 300 | 0x6A | 0x03 | 0x01 | Similar to Lenovo | Report |
| Swift 3 (SF314) | 0x6A | 0x03 | 0x01 | Same register | Report |

## MSI

| Model | Register | AUTO | INHIBIT | Notes | Source |
|-------|----------|------|---------|-------|--------|
| GF63 Thin | 0x6A | 0x03 | 0x01 | Same as Lenovo/Acer | Report |
| GP66 Leopard | 0x6A | 0x03 | 0x01 | Confirmed | Report |

---

## Common Patterns

| Pattern | Likely meaning |
|---------|----------------|
| 0x00 / 0x01 | Simple on/off toggle |
| 0x00 / 0x40 / 0x80 | Mode select (HP-style) |
| 0x01 / 0x03 | Charge limit (Lenovo-style: 0x03=100%, 0x01=60-80%) |
| 0x00 / 0x02 | On/off (EliteBook-style) |
| 0x40 / 0x45 | HP BDVO family |
| 0x80 / 0xC5 | Read-back variant (bit 7 = status flag) |
| 0x00 / 0x80 | Another read-back variant |

---

## How to Contribute

1. Find your register (see [GENERIC_GUIDE.md](GENERIC_GUIDE.md))
2. Fork this repo
3. Edit this file with your entry
4. Submit a Pull Request

### Template for PR

```markdown
| Your Model Here | 0x?? | 0x?? | 0x?? | Stable/Volatile, notes | Your Name |
```

Include:
- Laptop model and BIOS version
- Screenshot or log showing register read/write
- Whether tested on Windows, Linux, or both
