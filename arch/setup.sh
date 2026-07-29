#!/usr/bin/env bash
set -euo pipefail

# === Battery Charge Limiter — Arch Linux Installer ===
# Run as root: sudo bash setup.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    err "Must run as root: sudo bash setup.sh"
    exit 1
fi

log "=== Battery Charge Limiter — Arch Installer ==="
echo ""

# Create default config before anything else
CONFIG_FILE="/etc/battery-charge-limiter.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'CONF'
# Battery Charge Limiter Configuration
# Uncomment and change values as needed:

START_THRESHOLD=75
STOP_THRESHOLD=80
POLL_INTERVAL=60
CONF
    ok "Default config created at $CONFIG_FILE"
fi

# 1. Install acpi_call-dkms
log "[1/5] Installing acpi_call-dkms..."
if pacman -Qi acpi_call-dkms &>/dev/null; then
    ok "acpi_call-dkms already installed"
else
    pacman -Sy --noconfirm acpi_call-dkms || {
        warn "acpi_call-dkms not in repos. Trying AUR..."
        if command -v yay &>/dev/null; then
            yay -S --noconfirm acpi_call-dkms
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm acpi_call-dkms
        else
            err "Install acpi_call-dkms manually: yay -S acpi_call-dkms"
            exit 1
        fi
    }
    ok "acpi_call-dkms installed"
fi

# 2. Load acpi_call module
log "[2/5] Loading acpi_call module..."
modprobe acpi_call 2>/dev/null || {
    err "Failed to load acpi_call. Reboot or check dkms status: dkms status"
    exit 1
}
ok "acpi_call module loaded"

# Make it persistent
if ! grep -q "^acpi_call" /etc/modules-load.d/acpi_call.conf 2>/dev/null; then
    echo "acpi_call" > /etc/modules-load.d/acpi_call.conf
    ok "acpi_call added to modules-load.d"
fi

# 3. Install daemon
log "[3/5] Installing daemon..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/battery-charge-limiter" /usr/local/bin/battery-charge-limiter
chmod +x /usr/local/bin/battery-charge-limiter
ok "Daemon installed to /usr/local/bin/battery-charge-limiter"

# 4. Install & enable systemd service
log "[4/5] Installing systemd service..."
cp "$SCRIPT_DIR/battery-charge-limiter.service" /etc/systemd/system/battery-charge-limiter.service
systemctl daemon-reload
systemctl enable battery-charge-limiter.service
systemctl start battery-charge-limiter.service
ok "Service installed, enabled, and started"

# 5. Install helper aliases
log "[5/5] Installing helper aliases..."
ALIAS_FILE="/etc/profile.d/battery-charge-limiter.sh"
cat > "$ALIAS_FILE" << 'EOF'
# Battery Charge Limiter aliases
alias bat-inhibit='echo "\\_SB.WMID.SBCO BUFQ{0x00, 0x05, 0x00, 0x00}" | tee /proc/acpi/call && cat /proc/acpi/call && echo "Charging INHIBITED"'
alias bat-auto='echo "\\_SB.WMID.SBCC BUFQ{0x00, 0x00, 0x00, 0x00}" | tee /proc/acpi/call && cat /proc/acpi/call && echo "Charging AUTO restored"'
alias bat-status='echo "Battery status:" && cat /sys/class/power_supply/BAT0/capacity 2>/dev/null | xargs -I{} echo "    percentage:          {}%" && cat /sys/class/power_supply/BAT0/status 2>/dev/null | xargs -I{} echo "    charging status:     {}" && cat /sys/class/power_supply/BAT0/power_now 2>/dev/null | awk "{printf \"    power_now:           %.2f W\\n\", \$1/1000000}"'
EOF
chmod +x "$ALIAS_FILE"
ok "Aliases installed — relogin or 'source $ALIAS_FILE' to use"

echo ""
log "=== Setup Complete ==="
echo ""
echo "  Commands:"
echo "    bat-status     → Check battery level, status, power"
echo "    bat-inhibit    → Manually stop charging"
echo "    bat-auto       → Manually resume charging"
echo ""
echo "  Daemon manages automatically:"
echo "    systemctl status battery-charge-limiter"
echo "    journalctl -u battery-charge-limiter -f"
echo ""
echo "  Config: $CONFIG_FILE"
echo "    Edit thresholds: sudo nano $CONFIG_FILE"
echo "    Restart after edit: sudo systemctl restart battery-charge-limiter"
echo ""
echo "  Stop protection:"
echo "    sudo systemctl stop battery-charge-limiter"
echo ""
