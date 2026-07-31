#!/usr/bin/env bash
set -euo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log "=== Battery Charge Limiter — Arch Installer ==="
echo ""

# 1. Copy config (don't overwrite if exists)
CONFIG_FILE="/etc/battery-charge-limiter.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    ok "Config exists at $CONFIG_FILE"
else
    cp "$SCRIPT_DIR/battery-charge-limiter.conf" "$CONFIG_FILE" 2>/dev/null || {
        warn "battery-charge-limiter.conf not found alongside setup.sh"
    }
    ok "Default config created at $CONFIG_FILE"
fi

# 2. Install acpi_call
log "[1/4] Installing acpi_call..."
if pacman -Qi acpi_call &>/dev/null; then
    ok "acpi_call already installed"
else
    if pacman -Sy --noconfirm acpi_call 2>/dev/null; then
        ok "acpi_call installed from repos"
    else
        warn "acpi_call not found in official repos, trying AUR..."
        if command -v yay &>/dev/null; then
            yay -S --noconfirm acpi_call || {
                err "Failed to install acpi_call. Try manually: yay -S acpi_call"
                exit 1
            }
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm acpi_call || {
                err "Failed to install acpi_call. Try manually: paru -S acpi_call"
                exit 1
            }
        else
            err "AUR helper not found. Install acpi_call manually: yay -S acpi_call"
            exit 1
        fi
        ok "acpi_call installed from AUR"
    fi
fi

# 3. Load and verify module
log "[2/4] Loading acpi_call..."
if ! lsmod | grep -q "^acpi_call"; then
    modprobe acpi_call 2>/dev/null || {
        err "Failed to load acpi_call. Reboot or check dkms: dkms status"
        exit 1
    }
fi
ok "acpi_call module loaded"

# Make module persistent across reboots
if [[ ! -f /etc/modules-load.d/acpi_call.conf ]]; then
    echo "acpi_call" > /etc/modules-load.d/acpi_call.conf
    ok "acpi_call added to modules-load.d (loads on boot)"
else
    ok "acpi_call already in modules-load.d"
fi

# 4. Install daemon
log "[3/4] Installing daemon..."
cp "$SCRIPT_DIR/battery-charge-limiter" /usr/bin/battery-charge-limiter
chmod +x /usr/bin/battery-charge-limiter
cp "$SCRIPT_DIR/bat-status" /usr/bin/bat-status
chmod +x /usr/bin/bat-status
cp "$SCRIPT_DIR/bat-inhibit" /usr/bin/bat-inhibit
chmod +x /usr/bin/bat-inhibit
cp "$SCRIPT_DIR/bat-auto" /usr/bin/bat-auto
chmod +x /usr/bin/bat-auto
ok "Daemon + bat-* tools installed"

# 5. Install & enable systemd service
log "[4/4] Installing systemd service..."
cp "$SCRIPT_DIR/battery-charge-limiter.service" /etc/systemd/system/battery-charge-limiter.service
systemctl daemon-reload
systemctl enable battery-charge-limiter.service
systemctl start battery-charge-limiter.service
ok "Service installed, enabled, and started"

echo ""
log "=== Setup Complete ==="
echo ""
echo "  Commands:"
echo "    bat-status     → Battery level, health, power, cycles"
echo "    bat-inhibit    → Manually stop charging"
echo "    bat-auto       → Manually resume charging"
echo ""
echo "  Daemon management:"
echo "    systemctl status battery-charge-limiter"
echo "    journalctl -u battery-charge-limiter -f"
echo ""
echo "  Config: $CONFIG_FILE"
echo "    Edit: sudo nano $CONFIG_FILE"
echo "    Apply: sudo systemctl restart battery-charge-limiter"
echo ""
echo "  Stop protection:"
echo "    sudo systemctl stop battery-charge-limiter"
echo ""
