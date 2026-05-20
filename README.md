# fm-dx-pm2

**PM2 process manager setup for [fm-dx-webserver](https://github.com/noobishsvk/fm-dx-webserver) and optionally [fm-dx-monitoring](https://github.com/NoobishSVK/fm-dx-monitoring)**

This tool:
- Runs fm-dx-webserver (and optionally fm-dx-monitoring) under [PM2](https://pm2.keymetrics.io/) so they auto-restart on crash and survive reboots
- Installs a **pm2restart plugin** into fm-dx-webserver — no source code patching required
- The plugin adds a `/restart` HTTP endpoint (admin-only) and a **Restart Server** button to the admin Setup page
- When restarted via the button: **fm-dx-webserver restarts first**, then after a 20-second delay **fm-dx-monitoring restarts** (giving the webserver time to be fully up)

---

## Quick Install (Recommended)

```bash
git clone https://github.com/petertjeee/fm-dx-pm2.git
cd fm-dx-pm2
chmod +x install.sh
./install.sh
```

The script will ask for the path to fm-dx-webserver and whether you want to include fm-dx-monitoring, then do everything automatically.

> **Tested on:** Raspberry Pi OS (Bookworm/Bullseye), Node.js 18+

---

## Manual Installation (Step by Step)

If you prefer to do everything by hand, follow these steps exactly.

---

### Step 1 — Install PM2

PM2 is a production process manager for Node.js. Install it globally:

```bash
npm install -g pm2
```

Verify it installed correctly:

```bash
pm2 -v
```

---

### Step 2 — Create the PM2 ecosystem file

The ecosystem file tells PM2 about both apps — where they are and how to run them.

Create a file called `ecosystem.config.js` inside the cloned `fm-dx-pm2` directory:

```bash
nano ~/fm-dx-pm2/ecosystem.config.js
```

**Without fm-dx-monitoring** — paste this, replacing the `cwd` path:

```js
module.exports = {
  apps: [
    {
      name: 'fm-dx-webserver',
      script: 'index.js',
      cwd: '/home/pi/fm-dx-webserver',   // <-- change this
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
```

**With fm-dx-monitoring** — paste this instead, replacing both `cwd` paths:

```js
module.exports = {
  apps: [
    {
      name: 'fm-dx-webserver',
      script: 'index.js',
      cwd: '/home/pi/fm-dx-webserver',   // <-- change this
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
      script: 'bash',
      args: '-c "sleep 20 && node index.js"',
      cwd: '/home/pi/fm-dx-monitoring',  // <-- change this
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
```

---

### Step 3 — Start both apps with PM2

```bash
pm2 start ~/fm-dx-pm2/ecosystem.config.js
```

Check they are running:

```bash
pm2 status
```

You should see both `fm-dx-webserver` and `fm-dx-monitoring` listed as `online`.

Save the current PM2 process list so it survives a reboot:

```bash
pm2 save
```

---

### Step 4 — Enable PM2 auto-start on boot

This makes PM2 itself start automatically when the Raspberry Pi boots:

```bash
pm2 startup
```

PM2 will print a command that looks like this:

```
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u pi --hp /home/pi
```

**Copy that exact command and run it.** It registers PM2 as a systemd service.

---

### Step 5 — Allow PM2 to restart without a password prompt

The restart endpoint in fm-dx-webserver calls PM2 via the shell. By default this would require a `sudo` password, which won't work in a web request. We need to allow it passwordless.

Find where PM2 is installed:

```bash
which pm2
```

It will output something like `/usr/bin/pm2` or `/home/pi/.nvm/versions/node/v18.20.0/bin/pm2`.

Create a sudoers rule (replace `/usr/bin/pm2` with your actual path, and `pi` with your username):

```bash
sudo visudo -f /etc/sudoers.d/fm-dx-pm2
```

Add this single line (adjust path and username):

```
pi ALL=(ALL) NOPASSWD: /usr/bin/pm2
```

Save and exit (`Ctrl+X`, `Y`, `Enter` in nano).

Verify the file has the right permissions:

```bash
sudo chmod 440 /etc/sudoers.d/fm-dx-pm2
```

Test it works without a password:

```bash
sudo pm2 status
```

---

### Step 6 — Install the pm2restart plugin

Copy the plugin files into fm-dx-webserver's `plugins/` directory:

```bash
cp /path/to/fm-dx-pm2/plugin/pm2restart.js /home/pi/fm-dx-webserver/plugins/pm2restart.js
cp -r /path/to/fm-dx-pm2/plugin/pm2restart /home/pi/fm-dx-webserver/plugins/pm2restart
```

Now edit the installed backend file to set the correct restart command:

```bash
nano /home/pi/fm-dx-webserver/plugins/pm2restart.js
```

Find this line:

```js
const RESTART_CMD = 'PM2_RESTART_CMD';
```

Replace it with **one** of the following depending on your setup:

**Without fm-dx-monitoring:**
```js
const RESTART_CMD = 'pm2 restart fm-dx-webserver --update-env';
```

**With fm-dx-monitoring:**
```js
const RESTART_CMD = 'pm2 restart fm-dx-webserver --update-env; sleep 20 && pm2 restart fm-dx-monitoring --update-env';
```

Create the config file so the frontend shows the right description:

```bash
nano /home/pi/fm-dx-webserver/plugins/pm2restart/pm2restart-config.json
```

Paste:
```json
{
  "description": "Restart fm-dx-webserver via PM2. The page will reload automatically when the server is back online."
}
```

> **Restart order:** fm-dx-webserver restarts first. After a 20-second delay, fm-dx-monitoring restarts — by then the webserver is fully up and accepting connections.

---

### Step 7 — Enable the plugin in fm-dx-webserver

1. Log in to the fm-dx-webserver admin panel
2. Go to **Setup → Plugins**
3. Enable **PM2 Restart** from the list
4. Save settings and restart the server from the command line once:

```bash
pm2 restart fm-dx-webserver
```

---

### Step 8 — Test it

1. Open the fm-dx-webserver web interface in your browser
2. Log in as admin
3. Go to **Setup → Dashboard**
4. You should see a **Server Control** section with a **Restart Server** button
5. Click it — the server restarts, and the page reloads automatically when it is back

---

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

This will:
- Stop and remove both apps from PM2
- Remove the `pm2restart` plugin files from fm-dx-webserver
- Remove `pm2restart` from `settings.json`
- Remove the sudoers rule

---

## Useful PM2 Commands

| Command | Description |
|---|---|
| `pm2 status` | Show all running processes |
| `pm2 logs fm-dx-webserver` | Live log tail for webserver |
| `pm2 logs fm-dx-monitoring` | Live log tail for monitoring |
| `pm2 restart fm-dx-webserver` | Restart webserver only |
| `pm2 restart fm-dx-monitoring` | Restart monitoring only |
| `pm2 restart all` | Restart everything |
| `pm2 stop all` | Stop everything |
| `pm2 monit` | Interactive process monitor |

---

## Troubleshooting

**PM2 restart command fails silently**
- Check that `sudo pm2 status` works without a password prompt
- Verify the sudoers file path and username are correct (Step 5)

**Button shows "Request failed"**
- Make sure you are logged in as admin
- Check the browser console for the actual error
- Verify the `/restart` route was added correctly to `endpoints.js`

**fm-dx-monitoring still shows old data after restart**
- The 20-second delay is usually enough. If not, increase it in two places: the `args` field in `ecosystem.config.js` (startup delay) and the `RESTART_CMD` in the installed `plugins/pm2restart.js` (button restart delay), changing `sleep 20` to a higher value (e.g. `sleep 30`)

**Apps don't start on boot**
- Re-run `pm2 startup` and make sure you ran the printed `sudo env ...` command
- Re-run `pm2 save` after starting your apps

---

## License

MIT
