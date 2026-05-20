# Changelog

## v1.0.1

- Increased default `max_memory_restart` for fm-dx-webserver from 300M to 800M
- Increased default `max_memory_restart` for fm-dx-monitoring from 200M to 500M

## v1.0.0 — Initial Release

- Installs PM2 to manage fm-dx-webserver (and optionally fm-dx-monitoring)
- Installs the **pm2restart plugin** — no source code patching required
- Adds a **Restart Server** button to the fm-dx-webserver admin Setup page (Dashboard tab)
- Restart order: fm-dx-webserver first, fm-dx-monitoring after 20 seconds
- Detects and offers to disable conflicting systemd services (including pm2-root)
- Configures passwordless PM2 restart via sudoers
- Plugin includes update checker (badge + red dot in nav when update available)
- Warning if run as root — recommends running as the regular user
- Uses `sudo` only where strictly required (npm global install, sudoers, systemctl)
- Interactive install and uninstall scripts
- Plugin author set to `petertjeee`
