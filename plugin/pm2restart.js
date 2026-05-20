///////////////////////////////////////////////////////////////
///                                                         ///
///  PM2 RESTART PLUGIN FOR FM-DX-WEBSERVER                ///
///                                                         ///
///  Adds a /restart endpoint and a button in the Setup     ///
///  page dashboard. Requires PM2 to manage the process.    ///
///                                                         ///
///////////////////////////////////////////////////////////////

const path = require('path');
const { exec } = require('child_process');
const https = require('https');

// Plugin configuration
var pluginConfig = {
    name: 'PM2 Restart',
    version: '1.0.0',
    author: 'petertjeee',
    frontEndPath: 'pm2restart/frontend.js'
};

const PLUGIN_VERSION = pluginConfig.version;
const GITHUB_RAW_URL = 'https://raw.githubusercontent.com/petertjeee/fm-dx-pm2/main/plugin/pm2restart.js';

// Restart command — replaced by install.sh with the correct command
const RESTART_CMD = 'PM2_RESTART_CMD';

function logMsg(msg) {
    console.log(`[PM2Restart] ${msg}`);
}

function initRoute() {
    try {
        const pluginsApi = require(path.join(__dirname, '..', 'server', 'plugins_api'));
        const httpServer = pluginsApi.getHttpServer();

        if (!httpServer) {
            setTimeout(initRoute, 2000);
            return;
        }

        // Get the Express app from the http.Server request listeners
        const app = httpServer.listeners('request')[0];

        if (typeof app !== 'function') {
            logMsg('Could not obtain Express app from httpServer, retrying...');
            setTimeout(initRoute, 2000);
            return;
        }

        app.get('/restart', (req, res) => {
            if (!req.session || !req.session.isAdminAuthenticated) {
                return res.status(403).json({ message: 'Unauthorized' });
            }

            res.json({ ok: true, message: 'Restarting...' });
            logMsg('Restart triggered by admin');

            setTimeout(() => {
                exec(RESTART_CMD, (err) => {
                    if (err) {
                        logMsg('PM2 restart failed: ' + err.message);
                    } else {
                        logMsg('PM2 restart command executed successfully');
                    }
                });
            }, 500);
        });

        logMsg('Route /restart registered');
    } catch (e) {
        logMsg('Init postponed: ' + e.message);
        setTimeout(initRoute, 2000);
    }
}

setTimeout(initRoute, 3000);
setTimeout(checkForUpdate, 10000);

function checkForUpdate() {
    https.get(GITHUB_RAW_URL, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
            const match = data.match(/version: '([^']+)'/);
            if (!match) return;
            const remote = match[1];
            if (remote === PLUGIN_VERSION) return;

            const local = PLUGIN_VERSION.split('.').map(Number);
            const rem = remote.split('.').map(Number);
            let isNewer = false;
            for (let i = 0; i < Math.max(local.length, rem.length); i++) {
                if ((rem[i] || 0) > (local[i] || 0)) { isNewer = true; break; }
                if ((local[i] || 0) > (rem[i] || 0)) break;
            }
            if (isNewer) {
                logMsg(`Update available: ${PLUGIN_VERSION} → ${remote} (https://github.com/petertjeee/fm-dx-pm2)`);
            }
        });
    }).on('error', () => {});
}

// Don't change anything below here
module.exports = { pluginConfig };
