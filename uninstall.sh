#!/bin/bash
# =============================================================================
#  fm-dx-pm2 uninstaller
#  Removes PM2 apps and the pm2restart plugin
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}==> $1${NC}"; }

echo -e "${BOLD}\n  fm-dx-pm2 Uninstaller\n${NC}"

# Collect paths
DEFAULT_WEBSERVER="$HOME/fm-dx-webserver"
echo -e "${BOLD}Path to fm-dx-webserver${NC} (default: $DEFAULT_WEBSERVER)"
read -rp "  Enter path (or press Enter for default): " INPUT_WEBSERVER
WEBSERVER_PATH="${INPUT_WEBSERVER:-$DEFAULT_WEBSERVER}"
WEBSERVER_PATH="${WEBSERVER_PATH%/}"

# Stop and remove PM2 apps
step "Stopping PM2 apps"
pm2 delete fm-dx-webserver 2>/dev/null && success "Stopped fm-dx-webserver" || warn "fm-dx-webserver not running in PM2"
pm2 delete fm-dx-monitoring 2>/dev/null && success "Stopped fm-dx-monitoring" || warn "fm-dx-monitoring not running in PM2"
pm2 save

# Remove pm2restart plugin files
step "Removing pm2restart plugin"
PLUGIN_JS="$WEBSERVER_PATH/plugins/pm2restart.js"
PLUGIN_DIR="$WEBSERVER_PATH/plugins/pm2restart"

if [ -f "$PLUGIN_JS" ]; then
    rm "$PLUGIN_JS"
    success "Removed $PLUGIN_JS"
else
    warn "$PLUGIN_JS not found — skipping"
fi

if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    success "Removed $PLUGIN_DIR"
else
    warn "$PLUGIN_DIR not found — skipping"
fi

# Remove from settings.json plugins list if present
CONFIG_JSON="$WEBSERVER_PATH/settings.json"
if [ -f "$CONFIG_JSON" ] && grep -q '"pm2restart"' "$CONFIG_JSON"; then
    python3 - "$CONFIG_JSON" << 'PYEOF'
import sys, json
filepath = sys.argv[1]
with open(filepath, 'r') as f:
    cfg = json.load(f)
if 'plugins' in cfg and isinstance(cfg['plugins'], list):
    cfg['plugins'] = [p for p in cfg['plugins'] if p != 'pm2restart']
    with open(filepath, 'w') as f:
        json.dump(cfg, f, indent=2)
    print('pm2restart removed from plugins list')
PYEOF
    success "pm2restart removed from settings.json"
fi

# Remove sudoers rule
step "Removing sudoers rule"
SUDOERS_FILE="/etc/sudoers.d/fm-dx-pm2"
if sudo test -f "$SUDOERS_FILE"; then
    sudo rm "$SUDOERS_FILE"
    success "Sudoers rule removed"
else
    warn "No sudoers rule found at $SUDOERS_FILE — skipping"
fi

echo ""
echo -e "${GREEN}${BOLD}Uninstall complete.${NC}"
echo -e "  PM2 itself is still installed. To remove it: ${BOLD}npm uninstall -g pm2${NC}"
echo ""
