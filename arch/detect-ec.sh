#!/usr/bin/env bash
set -euo pipefail

# === EC Register Discovery for Linux ===
# Finds the EC register controlling battery charge on HP laptops.
# Uses ec_sys (debugfs) to dump and compare EC state.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

log "=== EC Register Discovery (Linux) ==="
echo ""

# Method 1: Check if acpi_call is available for WMI method testing
if [[ -f /proc/acpi/call ]]; then
    log "acpi_call available — can test WMI interface"
    log "Testing SBCC (AUTO) method..."
    echo "\\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}" > /proc/acpi/call 2>/dev/null
    result=$(cat /proc/acpi/call 2>/dev/null)
    echo "  Result: $result"

    log "Testing SBCO (INHIBIT) method..."
    echo "\\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}" > /proc/acpi/call 2>/dev/null
    result=$(cat /proc/acpi/call 2>/dev/null)
    echo "  Result: $result"
    echo ""
fi

# Method 2: ec_sys kernel module (direct EC register access)
log "Trying ec_sys kernel module..."
modprobe ec_sys 2>/dev/null || warn "ec_sys not available (try: modprobe ec_sys)"

EC_DEBUG="/sys/kernel/debug/ec/ec0/io"
if [[ -r "$EC_DEBUG" ]]; then
    ok "ec_sys loaded — EC register dump available at $EC_DEBUG"
    echo ""
    log "Current EC register state (offset 0x00-0xFF):"
    echo ""
    xxd "$EC_DEBUG" | head -20
    echo ""
    warn "To find the charge control register:"
    echo "  1. Plug in AC and charge battery > 80%"
    echo "  2. Save dump: cp $EC_DEBUG /tmp/ec_charging"
    echo "  3. Unplug AC and let drain a bit"
    echo "  4. Save dump: cp $EC_DEBUG /tmp/ec_discharging"
    echo "  5. Compare: diff <(xxd /tmp/ec_charging) <(xxd /tmp/ec_discharging)"
    echo ""
    log "Known charge control registers on HP:"
    echo "  Register   AUTO    INHIBIT   Models"
    echo "  ─────────────────────────────────────────"
    echo "  0x76       0x40    0x45      HP Pavilion 15-eg3xxx"
    echo "  0xD7       0x00    0x02      HP EliteBook 8xx G6+"
    echo "  0x69       0x00    0x01      HP EliteBook 845 G8"
    echo ""
    log "Testing known register 0x76..."
    current_76=$(xxd "$EC_DEBUG" | grep "^0000000" | awk '{print $8}')
    echo "  EC[0x76] = 0x$current_76"
else
    warn "ec_sys not available. Install: modprobe ec_sys"
    warn "If not found, rebuild kernel with CONFIG_EC_SYS=y or load as module."
    echo ""
    log "Alternative: Use acpi_call to check WMI availability:"
    echo "  echo '\\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}' > /proc/acpi/call"
    echo "  cat /proc/acpi/call"
    echo ""
    log "For manual register discovery on Windows, see:"
    echo "  docs/ec-register-discovery.md"
fi

echo ""
log "=== Known HP Pavilion 15-eg3xxx Values ==="
echo ""
echo "  Register:   BDVO @ offset 0x76"
echo "  AUTO:       0x40 (resume charging)"
echo "  INHIBIT:    0x45 (stop charging)"
echo "  Read-back:  0x80 (AUTO), 0xC5 (INHIBIT)"
echo ""
echo "  ACPI WMI methods (via acpi_call):"
echo "    AUTO:    \\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}"
echo "    INHIBIT: \\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}"
echo "    STATUS:  \\_SB.WMID.WMGG BUFQ{0x00, 0x01, 0x00, 0x00}"
