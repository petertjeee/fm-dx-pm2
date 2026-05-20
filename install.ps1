# =============================================================================
#  fm-dx-pm2 installer for Windows
#  Configures PM2 to manage fm-dx-webserver (+ optionally fm-dx-monitoring),
#  and installs the pm2restart plugin (no source code patching).
#
#  Run in PowerShell as Administrator:
#    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#    .\install.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'

$RED    = 'Red'
$GREEN  = 'Green'
$YELLOW = 'Yellow'
$CYAN   = 'Cyan'
$WHITE  = 'White'

function Info    ($msg) { Write-Host "[INFO] $msg"    -ForegroundColor $CYAN   }
function Success ($msg) { Write-Host "[OK]   $msg"    -ForegroundColor $GREEN  }
function Warn    ($msg) { Write-Host "[WARN] $msg"    -ForegroundColor $YELLOW }
function Err     ($msg) { Write-Host "[ERROR] $msg"   -ForegroundColor $RED; exit 1 }
function Step    ($msg) { Write-Host "`n==> $msg"     -ForegroundColor $WHITE  }

Write-Host @"

  ███████╗███╗   ███╗      ██████╗ ██╗  ██╗    ██████╗ ███╗   ███╗██████╗
  ██╔════╝████╗ ████║      ██╔══██╗╚██╗██╔╝    ██╔══██╗████╗ ████║╚════██╗
  █████╗  ██╔████╔██║█████╗██║  ██║ ╚███╔╝     ██████╔╝██╔████╔██║ █████╔╝
  ██╔══╝  ██║╚██╔╝██║╚════╝██║  ██║ ██╔██╗     ██╔═══╝ ██║╚██╔╝██║██╔═══╝
  ██║     ██║ ╚═╝ ██║      ██████╔╝██╔╝ ██╗    ██║     ██║ ╚═╝ ██║███████╗
  ╚═╝     ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝    ╚═╝     ╚═╝     ╚═╝╚══════╝

  PM2 process manager setup for fm-dx-webserver (+ optional fm-dx-monitoring)
  Installs the pm2restart plugin - no source code patching required.

"@ -ForegroundColor White

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# =============================================================================
# STEP 1 — Check prerequisites
# =============================================================================
Step "Checking prerequisites"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Warn "This script is not running as Administrator."
    Warn "Some steps (auto-startup via pm2-windows-startup) may require elevation."
    $continue = Read-Host "  Continue anyway? [y/N]"
    if ($continue -notmatch '^[Yy]$') { exit 1 }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Err "Node.js is not installed. Install it first: https://nodejs.org"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Err "npm is not installed."
}
$nodeVer = node -v
Success "Node.js $nodeVer found"

# =============================================================================
# STEP 2 — Install PM2 globally if not present
# =============================================================================
Step "Installing PM2"

if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    $pm2Ver = pm2 -v
    Success "PM2 $pm2Ver already installed"
} else {
    Info "Installing PM2 globally..."
    npm install -g pm2
    if ($LASTEXITCODE -ne 0) { Err "Failed to install PM2." }
    Success "PM2 installed"
}

# =============================================================================
# STEP 3 — Collect paths
# =============================================================================
Step "Configuring paths"

$defaultWebserver = "$env:USERPROFILE\fm-dx-webserver"
Write-Host "`nPath to fm-dx-webserver (default: $defaultWebserver)"
$inputWebserver = Read-Host "  Enter path (or press Enter for default)"
$webserverPath = if ($inputWebserver) { $inputWebserver.TrimEnd('\') } else { $defaultWebserver }

if (-not (Test-Path $webserverPath -PathType Container)) { Err "Directory not found: $webserverPath" }
if (-not (Test-Path "$webserverPath\index.js")) { Err "index.js not found in $webserverPath — is this the right directory?" }
Success "fm-dx-webserver: $webserverPath"

$useMonitoring = $false
$monitoringPath = ''

Write-Host ""
$wantMonitoring = Read-Host "  Include fm-dx-monitoring? [y/N]"
if ($wantMonitoring -match '^[Yy]$') {
    $useMonitoring = $true
    $defaultMonitoring = "$env:USERPROFILE\fm-dx-monitoring"
    Write-Host "`nPath to fm-dx-monitoring (default: $defaultMonitoring)"
    $inputMonitoring = Read-Host "  Enter path (or press Enter for default)"
    $monitoringPath = if ($inputMonitoring) { $inputMonitoring.TrimEnd('\') } else { $defaultMonitoring }

    if (-not (Test-Path $monitoringPath -PathType Container)) { Err "Directory not found: $monitoringPath" }
    if (-not (Test-Path "$monitoringPath\index.js")) { Err "index.js not found in $monitoringPath — is this the right directory?" }
    Success "fm-dx-monitoring: $monitoringPath"
} else {
    Info "fm-dx-monitoring skipped"
}

# =============================================================================
# STEP 4 — Write ecosystem.config.js
# =============================================================================
Step "Writing ecosystem.config.js"

$ecosystemPath = "$SCRIPT_DIR\ecosystem.config.js"

if ($useMonitoring) {
    $ecosystemContent = @"
module.exports = {
  apps: [
    {
      name: 'fm-dx-webserver',
      script: 'index.js',
      cwd: '$($webserverPath -replace '\\', '\\')',
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
      cwd: '$($monitoringPath -replace '\\', '\\')',
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
"@
} else {
    $ecosystemContent = @"
module.exports = {
  apps: [
    {
      name: 'fm-dx-webserver',
      script: 'index.js',
      cwd: '$($webserverPath -replace '\\', '\\')',
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
"@
}

Set-Content -Path $ecosystemPath -Value $ecosystemContent -Encoding UTF8
Success "Written: $ecosystemPath"

# =============================================================================
# STEP 5 — Install pm2restart plugin
# =============================================================================
Step "Installing pm2restart plugin"

$pluginSrc = "$SCRIPT_DIR\plugin"
$pluginDst = "$webserverPath\plugins"

if (-not (Test-Path $pluginSrc)) { Err "Plugin source directory not found: $pluginSrc" }
if (-not (Test-Path $pluginDst)) { Err "Plugins directory not found in fm-dx-webserver: $pluginDst" }

# Copy delay-start.js to monitoring directory if needed
if ($useMonitoring) {
    Copy-Item "$pluginSrc\delay-start.js" "$monitoringPath\delay-start.js" -Force
    Success "Copied delay-start.js to $monitoringPath"
}

# Build restart command (Windows: pm2 runs as same user, no sudo needed)
if ($useMonitoring) {
    $restartCmd = "pm2 restart fm-dx-webserver --update-env && timeout /t 20 /nobreak >nul && pm2 restart fm-dx-monitoring --update-env"
    $description = "Restart fm-dx-webserver and fm-dx-monitoring. fm-dx-monitoring restarts automatically 20 seconds after the webserver."
} else {
    $restartCmd = "pm2 restart fm-dx-webserver --update-env"
    $description = "Restart fm-dx-webserver via PM2. The page will reload automatically when the server is back online."
}

# Copy and patch plugin backend
Copy-Item "$pluginSrc\pm2restart.js" "$pluginDst\pm2restart.js" -Force
$pluginContent = Get-Content "$pluginDst\pm2restart.js" -Raw
$pluginContent = $pluginContent -replace 'PM2_RESTART_CMD', $restartCmd
Set-Content -Path "$pluginDst\pm2restart.js" -Value $pluginContent -Encoding UTF8

# Copy plugin frontend folder
if (Test-Path "$pluginDst\pm2restart") { Remove-Item "$pluginDst\pm2restart" -Recurse -Force }
Copy-Item "$pluginSrc\pm2restart" "$pluginDst\pm2restart" -Recurse -Force

# Write pm2restart-config.json
$configJson = @{ description = $description } | ConvertTo-Json
Set-Content -Path "$pluginDst\pm2restart\pm2restart-config.json" -Value $configJson -Encoding UTF8

# Enable plugin in settings.json if present
$settingsJson = "$webserverPath\settings.json"
if (Test-Path $settingsJson) {
    $settings = Get-Content $settingsJson -Raw | ConvertFrom-Json
    if ($settings.PSObject.Properties['plugins'] -and $settings.plugins -is [array]) {
        if ($settings.plugins -notcontains 'pm2restart') {
            $settings.plugins += 'pm2restart'
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsJson -Encoding UTF8
            Info "pm2restart added to plugins list in settings.json"
        } else {
            Warn "pm2restart already listed in settings.json"
        }
    } else {
        Warn "No plugins array found in settings.json — enable pm2restart manually in the admin panel under Setup > Plugins"
    }
} else {
    Warn "settings.json not found — enable pm2restart manually in the admin panel under Setup > Plugins"
}

Success "Plugin installed: $pluginDst\pm2restart.js + $pluginDst\pm2restart\"

# =============================================================================
# STEP 6 — Install pm2-windows-startup for auto-start on boot
# =============================================================================
Step "Configuring auto-start on boot"

if (Get-Command pm2-startup -ErrorAction SilentlyContinue) {
    Success "pm2-windows-startup already installed"
} else {
    Info "Installing pm2-windows-startup..."
    npm install -g pm2-windows-startup
    if ($LASTEXITCODE -ne 0) {
        Warn "Failed to install pm2-windows-startup. Auto-start on boot will not be configured."
        Warn "Install it manually later: npm install -g pm2-windows-startup"
    } else {
        Success "pm2-windows-startup installed"
    }
}

# =============================================================================
# STEP 7 — Start apps with PM2
# =============================================================================
Step "Starting apps with PM2"

Write-Host ""
$startNow = Read-Host "  Start both apps with PM2 now? [Y/n]"
$startNow = if ($startNow) { $startNow } else { 'Y' }

if ($startNow -match '^[Yy]$') {
    pm2 delete fm-dx-webserver 2>$null
    if ($useMonitoring) { pm2 delete fm-dx-monitoring 2>$null }

    pm2 start $ecosystemPath
    pm2 save
    Success "Apps started and saved"

    # Register PM2 to start on boot
    if (Get-Command pm2-startup -ErrorAction SilentlyContinue) {
        pm2-startup install
        Success "PM2 registered to start on Windows boot"
    } else {
        Warn "pm2-windows-startup not available — run 'pm2-startup install' manually after installing it"
    }
} else {
    Info "Skipped. Start manually with: pm2 start `"$ecosystemPath`""
}

# =============================================================================
# Done
# =============================================================================
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Useful commands:" -ForegroundColor White
Write-Host "  pm2 status                    - show running processes"
Write-Host "  pm2 logs fm-dx-webserver      - tail webserver logs"
if ($useMonitoring) {
    Write-Host "  pm2 logs fm-dx-monitoring     - tail monitoring logs"
}
Write-Host "  pm2 restart fm-dx-webserver   - restart webserver only"
if ($useMonitoring) {
    Write-Host "  pm2 restart all               - restart everything"
}
Write-Host "  pm2 stop all                  - stop everything"
Write-Host ""
Write-Host "  Restart button: Log in to the webserver admin panel -> Setup -> Dashboard" -ForegroundColor White
Write-Host ""
