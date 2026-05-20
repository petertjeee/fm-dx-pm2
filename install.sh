#!/bin/bash
# =============================================================================
#  fm-dx-pm2 installer
#  Configures PM2 to manage fm-dx-webserver (+ optionally fm-dx-monitoring),
#  and installs the pm2restart plugin (no source code patching).
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}==> $1${NC}"; }

echo -e "${BOLD}"
echo "  ███████╗███╗   ███╗      ██████╗ ██╗  ██╗    ██████╗ ███╗   ███╗██████╗ "
echo "  ██╔════╝████╗ ████║      ██╔══██╗╚██╗██╔╝    ██╔══██╗████╗ ████║╚════██╗"
echo "  █████╗  ██╔████╔██║█████╗██║  ██║ ╚███╔╝     ██████╔╝██╔████╔██║ █████╔╝"
echo "  ██╔══╝  ██║╚██╔╝██║╚════╝██║  ██║ ██╔██╗     ██╔═══╝ ██║╚██╔╝██║██╔═══╝ "
echo "  ██║     ██║ ╚═╝ ██║      ██████╔╝██╔╝ ██╗    ██║     ██║ ╚═╝ ██║███████╗"
echo "  ╚═╝     ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝    ╚═╝     ╚═╝     ╚═╝╚══════╝"
echo -e "${NC}"
echo -e "  PM2 process manager setup for fm-dx-webserver (+ optional fm-dx-monitoring)\n"
echo -e "  Installs the pm2restart plugin — no source code patching required.\n"

# =============================================================================
# STEP 1 — Check prerequisites
# =============================================================================
step "Checking prerequisites"

if [ "$(id -u)" -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠  WARNING: You are running this script as root!${NC}"
    echo ""
    echo -e "  Running PM2 and fm-dx-webserver as root is not recommended."
    echo -e "  It means the web server process has full system access."
    echo ""
    echo -e "  ${BOLD}Recommended:${NC} exit now and run as the regular user that owns fm-dx-webserver."
    echo -e "  Example:  ${BOLD}su - fmdx${NC}  then re-run this script."
    echo ""
    read -rp "  Continue as root anyway? [y/N]: " ROOT_CONTINUE
    ROOT_CONTINUE="${ROOT_CONTINUE:-N}"
    if [[ ! "$ROOT_CONTINUE" =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Aborted. Please re-run as the correct user."
        echo ""
        exit 1
    fi
    warn "Continuing as root — you have been warned."
fi

command -v node >/dev/null 2>&1 || error "Node.js is not installed. Install it first: https://nodejs.org"
command -v npm  >/dev/null 2>&1 || error "npm is not installed."
NODE_VER=$(node -v)
success "Node.js $NODE_VER found"

# =============================================================================
# STEP 2 — Install PM2 globally if not present
# =============================================================================
step "Installing PM2"

if command -v pm2 >/dev/null 2>&1; then
    PM2_VER=$(pm2 -v)
    success "PM2 $PM2_VER already installed"
else
    info "Installing PM2 globally (requires npm)..."
    if [ "$(id -u)" -eq 0 ]; then
        npm install -g pm2 || error "Failed to install PM2."
    else
        sudo npm install -g pm2 || error "Failed to install PM2. Try running: sudo npm install -g pm2"
    fi
    success "PM2 installed"
fi

# =============================================================================
# STEP 3 — Collect paths
# =============================================================================
step "Configuring paths"

# fm-dx-webserver path
DEFAULT_WEBSERVER="$HOME/fm-dx-webserver"
echo -e "\n${BOLD}Path to fm-dx-webserver${NC} (default: $DEFAULT_WEBSERVER)"
read -rp "  Enter path (or press Enter for default): " INPUT_WEBSERVER
WEBSERVER_PATH="${INPUT_WEBSERVER:-$DEFAULT_WEBSERVER}"
WEBSERVER_PATH="${WEBSERVER_PATH%/}"  # strip trailing slash

[ -d "$WEBSERVER_PATH" ] || error "Directory not found: $WEBSERVER_PATH"
[ -f "$WEBSERVER_PATH/index.js" ] || error "index.js not found in $WEBSERVER_PATH — is this the right directory?"
success "fm-dx-webserver: $WEBSERVER_PATH"

# fm-dx-monitoring (optional)
USE_MONITORING=false
MONITORING_PATH=""

echo ""
read -rp "  Include fm-dx-monitoring? [y/N]: " WANT_MONITORING
WANT_MONITORING="${WANT_MONITORING:-N}"

if [[ "$WANT_MONITORING" =~ ^[Yy]$ ]]; then
    USE_MONITORING=true
    DEFAULT_MONITORING="$HOME/fm-dx-monitoring"
    echo -e "\n${BOLD}Path to fm-dx-monitoring${NC} (default: $DEFAULT_MONITORING)"
    read -rp "  Enter path (or press Enter for default): " INPUT_MONITORING
    MONITORING_PATH="${INPUT_MONITORING:-$DEFAULT_MONITORING}"
    MONITORING_PATH="${MONITORING_PATH%/}"

    [ -d "$MONITORING_PATH" ] || error "Directory not found: $MONITORING_PATH"
    [ -f "$MONITORING_PATH/index.js" ] || error "index.js not found in $MONITORING_PATH — is this the right directory?"
    success "fm-dx-monitoring: $MONITORING_PATH"
else
    info "fm-dx-monitoring skipped"
fi

# =============================================================================
# STEP 4 — Write ecosystem.config.js
# =============================================================================
step "Writing ecosystem.config.js"

ECOSYSTEM_PATH="$SCRIPT_DIR/ecosystem.config.js"

if [ "$USE_MONITORING" = true ]; then
cat > "$ECOSYSTEM_PATH" << EOF
module.exports = {
  apps: [
    {
      name: 'fm-dx-webserver',
      script: 'index.js',
      cwd: '$WEBSERVER_PATH',
      restart_delay: 2000,
      autorestart: true,
      watch: false,
      max_memory_restart: '800M',
      env: {
        NODE_ENV: 'production'
      }
    },
    {
      name: 'fm-dx-monitoring',
      script: 'delay-start.js',
      cwd: '$MONITORING_PATH',
      restart_delay: 2000,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
EOF
else
cat > "$ECOSYSTEM_PATH" << EOF
module.exports = {
  apps: [
    {
      name: 'fm-dx-webserver',
      script: 'index.js',
      cwd: '$WEBSERVER_PATH',
      restart_delay: 2000,
      autorestart: true,
      watch: false,
      max_memory_restart: '800M',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
EOF
fi

success "Written: $ECOSYSTEM_PATH"

# =============================================================================
# STEP 5 — Install pm2restart plugin
# =============================================================================
step "Installing pm2restart plugin"

PLUGIN_SRC="$SCRIPT_DIR/plugin"
PLUGIN_DST="$WEBSERVER_PATH/plugins"

[ -d "$PLUGIN_SRC" ] || error "Plugin source directory not found: $PLUGIN_SRC"
[ -d "$PLUGIN_DST" ] || error "Plugins directory not found in fm-dx-webserver: $PLUGIN_DST"

# Build restart command
if [ "$USE_MONITORING" = true ]; then
    RESTART_CMD="pm2 restart fm-dx-webserver --update-env; sleep 20 && pm2 restart fm-dx-monitoring --update-env"
else
    RESTART_CMD="pm2 restart fm-dx-webserver --update-env"
fi

# Build description for UI
if [ "$USE_MONITORING" = true ]; then
    DESCRIPTION="Restart fm-dx-webserver and fm-dx-monitoring. fm-dx-monitoring restarts automatically 20 seconds after the webserver."
else
    DESCRIPTION="Restart fm-dx-webserver via PM2. The page will reload automatically when the server is back online."
fi

# Copy delay-start.js to monitoring directory if needed
if [ "$USE_MONITORING" = true ]; then
    cp "$SCRIPT_DIR/delay-start.js" "$MONITORING_PATH/delay-start.js"
    success "Copied delay-start.js to $MONITORING_PATH"
fi

# Copy plugin backend
cp "$PLUGIN_SRC/pm2restart.js" "$PLUGIN_DST/pm2restart.js"

# Substitute the actual restart command into the plugin
sed -i "s|PM2_RESTART_CMD|$RESTART_CMD|g" "$PLUGIN_DST/pm2restart.js"

# Copy plugin frontend folder
rm -rf "$PLUGIN_DST/pm2restart"
cp -r "$PLUGIN_SRC/pm2restart" "$PLUGIN_DST/pm2restart"

# Write pm2restart-config.json with description for the frontend
cat > "$PLUGIN_DST/pm2restart/pm2restart-config.json" << EOF
{
  "description": "$DESCRIPTION"
}
EOF

# Enable the plugin in fm-dx-webserver config if not already present
CONFIG_JSON="$WEBSERVER_PATH/settings.json"
if [ -f "$CONFIG_JSON" ]; then
    if grep -q '"pm2restart"' "$CONFIG_JSON"; then
        warn "pm2restart already listed in settings.json"
    else
        python3 - "$CONFIG_JSON" << 'PYEOF'
import sys, json
filepath = sys.argv[1]
with open(filepath, 'r') as f:
    cfg = json.load(f)
if 'plugins' in cfg and isinstance(cfg['plugins'], list):
    if 'pm2restart' not in cfg['plugins']:
        cfg['plugins'].append('pm2restart')
        with open(filepath, 'w') as f:
            json.dump(cfg, f, indent=2)
        print('pm2restart added to plugins list')
    else:
        print('pm2restart already in plugins list')
else:
    print('No plugins array found in settings.json — add pm2restart manually')
PYEOF
    fi
else
    warn "settings.json not found — enable pm2restart manually in the webserver admin panel under Setup > Plugins"
fi

success "Plugin installed: $PLUGIN_DST/pm2restart.js + $PLUGIN_DST/pm2restart/"

# =============================================================================
# STEP 6 — Configure sudoers (allow passwordless PM2 restart)
# =============================================================================
step "Configuring sudoers for PM2"

CURRENT_USER=$(whoami)
PM2_BIN=$(which pm2)

SUDOERS_LINE="$CURRENT_USER ALL=(ALL) NOPASSWD: $PM2_BIN"
SUDOERS_FILE="/etc/sudoers.d/fm-dx-pm2"

if sudo grep -qF "$PM2_BIN" /etc/sudoers 2>/dev/null || sudo test -f "$SUDOERS_FILE" 2>/dev/null; then
    warn "PM2 sudoers rule already exists — skipping"
else
    info "Writing sudoers rule (will prompt for sudo password)..."
    echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    success "Sudoers rule written: $SUDOERS_FILE"
fi

# =============================================================================
# STEP 7 — Check for conflicting systemd services
# (runs after sudoers so sudo is already configured)
# =============================================================================
step "Checking for existing systemd services"

check_and_disable_service() {
    local SERVICE_NAME="$1"
    local DISPLAY_NAME="$2"

    # Check common service file locations
    local SERVICE_FILE=""
    for f in \
        "/etc/systemd/system/${SERVICE_NAME}.service" \
        "/lib/systemd/system/${SERVICE_NAME}.service" \
        "/usr/lib/systemd/system/${SERVICE_NAME}.service"; do
        if [ -f "$f" ]; then
            SERVICE_FILE="$f"
            break
        fi
    done

    # Also check if systemd knows about it (handles masked/generated units)
    local IS_ENABLED=false
    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        IS_ENABLED=true
    fi

    if [ -n "$SERVICE_FILE" ] || [ "$IS_ENABLED" = true ]; then
        echo ""
        warn "Found existing systemd service for ${DISPLAY_NAME}: ${SERVICE_FILE:-$SERVICE_NAME}"
        local STATUS
        STATUS=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "unknown")
        info "Service status: $STATUS"
        echo ""
        read -rp "  Disable and stop this systemd service so PM2 can take over? [Y/n]: " DISABLE_IT
        DISABLE_IT="${DISABLE_IT:-Y}"
        if [[ "$DISABLE_IT" =~ ^[Yy]$ ]]; then
            sudo systemctl stop "$SERVICE_NAME" 2>/dev/null && info "Stopped $SERVICE_NAME" || true
            sudo systemctl disable "$SERVICE_NAME" 2>/dev/null && success "Disabled $SERVICE_NAME" || warn "Could not disable $SERVICE_NAME — disable it manually"
        else
            warn "Skipped. Note: both systemd and PM2 managing the same process may cause conflicts."
        fi
    else
        success "No systemd service found for ${DISPLAY_NAME}"
    fi
}

check_and_disable_service "fm-dx-webserver" "fm-dx-webserver"
if [ "$USE_MONITORING" = true ]; then
    check_and_disable_service "fm-dx-monitoring" "fm-dx-monitoring"
fi

# Check if a PM2 startup unit for root already exists
PM2_ROOT_UNIT="/etc/systemd/system/pm2-root.service"
if [ -f "$PM2_ROOT_UNIT" ] || systemctl is-enabled pm2-root >/dev/null 2>&1; then
    echo ""
    warn "Found a PM2 startup service running as root: pm2-root"
    echo -e "  This means PM2 (and all its apps) start as root on boot."
    echo -e "  ${BOLD}Recommended fix:${NC}"
    echo -e "    1. sudo systemctl disable pm2-root"
    echo -e "    2. sudo systemctl stop pm2-root"
    CURRENT_USER_NAME=$(whoami)
    echo -e "    3. Run ${BOLD}pm2 startup${NC} as ${BOLD}${CURRENT_USER_NAME}${NC} and run the command it prints"
    echo ""
    read -rp "  Disable pm2-root service now? [Y/n]: " DISABLE_PM2_ROOT
    DISABLE_PM2_ROOT="${DISABLE_PM2_ROOT:-Y}"
    if [[ "$DISABLE_PM2_ROOT" =~ ^[Yy]$ ]]; then
        sudo systemctl stop pm2-root 2>/dev/null || true
        sudo systemctl disable pm2-root 2>/dev/null && success "pm2-root disabled" || warn "Could not disable pm2-root — run: sudo systemctl disable pm2-root"
    else
        warn "Skipped. PM2 will still start as root on next boot."
    fi
fi

# =============================================================================
# STEP 8 — Start apps with PM2
# =============================================================================
step "Starting apps with PM2"

echo ""
read -rp "  Start both apps with PM2 now? [Y/n]: " START_NOW
START_NOW="${START_NOW:-Y}"

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    # Stop existing PM2 instances if running
    pm2 delete fm-dx-webserver 2>/dev/null || true
    if [ "$USE_MONITORING" = true ]; then
        pm2 delete fm-dx-monitoring 2>/dev/null || true
    fi

    pm2 start "$ECOSYSTEM_PATH"
    pm2 save
    success "Apps started and saved"

    echo ""
    STARTUP_USER=$(whoami)
    info "To enable auto-start on boot, run the command printed by:"
    echo -e "  ${BOLD}pm2 startup${NC}"
    echo -e "  (copy and run the 'sudo env ...' command it outputs)\n"
    STARTUP_CMD=$(pm2 startup 2>&1 | grep "sudo" | head -1)
    if [ -n "$STARTUP_CMD" ]; then
        echo -e "  ${YELLOW}Run this:${NC} $STARTUP_CMD"
        if echo "$STARTUP_CMD" | grep -q 'pm2-root'; then
            echo ""
            warn "The startup command above will register PM2 as root."
            echo -e "  To run as ${BOLD}${STARTUP_USER}${NC} instead, make sure you are NOT in a root shell"
            echo -e "  and run ${BOLD}pm2 startup${NC} again as ${BOLD}${STARTUP_USER}${NC}."
        fi
    fi
else
    info "Skipped. Start manually with: pm2 start $ECOSYSTEM_PATH"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "  pm2 status                    — show running processes"
echo -e "  pm2 logs fm-dx-webserver      — tail webserver logs"
if [ "$USE_MONITORING" = true ]; then
echo -e "  pm2 logs fm-dx-monitoring     — tail monitoring logs"
fi
echo -e "  pm2 restart fm-dx-webserver   — restart webserver only"
if [ "$USE_MONITORING" = true ]; then
echo -e "  pm2 restart all               — restart everything"
fi
echo -e "  pm2 stop all                  — stop everything"
echo ""
echo -e "  ${BOLD}Restart button:${NC} Log in to the webserver admin panel → Setup → Dashboard"
echo ""
