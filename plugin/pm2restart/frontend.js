///////////////////////////////////////////////////////////////
///                                                         ///
///  PM2 RESTART FRONTEND FOR FM-DX-WEBSERVER              ///
///                                                         ///
///  Injects a Restart Server button into the Setup page    ///
///  dashboard. Only visible to admin users.                ///
///                                                         ///
///////////////////////////////////////////////////////////////

(() => {
    'use strict';

    const PLUGIN_VERSION = '1.0.0';
    const PLUGIN_NAME = 'PM2 Restart';
    const PLUGIN_HOMEPAGE_URL = 'https://github.com/petertjeee/fm-dx-pm2/releases';
    const PLUGIN_UPDATE_URL = 'https://raw.githubusercontent.com/petertjeee/fm-dx-pm2/main/plugin/pm2restart.js';
    const CHECK_FOR_UPDATES = true;

    // Only inject on the setup page (/setup is admin-only — no further check needed)
    function shouldInject() {
        return window.location.pathname.includes('/setup');
    }

    function injectButton() {
        if (!shouldInject()) return;

        // Avoid double-inject
        if (document.getElementById('pm2restart-panel')) return;

        // Find the Dashboard h2 heading as insertion anchor
        const heading = Array.from(document.querySelectorAll('h2'))
            .find(el => el.textContent.trim() === 'Dashboard');

        if (!heading) return;

        const panel = document.createElement('div');
        panel.id = 'pm2restart-panel';
        panel.className = 'panel-100-real p-bottom-20';
        panel.innerHTML = `
            <h3>Server Control</h3>
            <p id="pm2restart-desc"></p>
            <button id="pm2restart-btn" class="button">
                <i class="fa-solid fa-rotate-right"></i> Restart Server
            </button>
            <span id="pm2restart-status" style="margin-left: 12px;"></span>
        `;

        heading.insertAdjacentElement('afterend', panel);

        // Fetch description from plugin config
        fetch('/js/plugins/pm2restart/pm2restart-config.json')
            .then(r => r.ok ? r.json() : null)
            .then(cfg => {
                const desc = document.getElementById('pm2restart-desc');
                if (desc && cfg && cfg.description) {
                    desc.textContent = cfg.description;
                } else if (desc) {
                    desc.textContent = 'Restart fm-dx-webserver via PM2. The page will reload automatically when the server is back online.';
                }
            })
            .catch(() => {
                const desc = document.getElementById('pm2restart-desc');
                if (desc) desc.textContent = 'Restart fm-dx-webserver via PM2. The page will reload automatically when the server is back online.';
            });

        document.getElementById('pm2restart-btn').addEventListener('click', () => {
            const confirmMsg = document.getElementById('pm2restart-desc')?.dataset?.confirm
                || 'Restart the server?';

            if (!confirm(confirmMsg)) return;

            const btn = document.getElementById('pm2restart-btn');
            const status = document.getElementById('pm2restart-status');

            btn.disabled = true;
            status.textContent = 'Restarting...';

            fetch('/restart')
                .then(r => r.json())
                .then(() => {
                    status.textContent = 'Waiting for server to come back online...';
                    const poll = setInterval(() => {
                        fetch('/ping')
                            .then(r => {
                                if (r.ok) {
                                    clearInterval(poll);
                                    status.textContent = 'Server is back! Reloading...';
                                    setTimeout(() => location.reload(), 1000);
                                }
                            })
                            .catch(() => {});
                    }, 2000);
                })
                .catch(() => {
                    status.textContent = 'Request failed.';
                    btn.disabled = false;
                });
        });

        console.log('[PM2Restart] Restart button injected');
    }

    function checkForUpdate() {
        if (window.location.pathname !== '/setup') return;

        const versionRegex = /const\s+(?:pluginVersion|plugin_version|PLUGIN_VERSION)\s*=\s*['"]([^'"]+)['"]/;

        fetch(PLUGIN_UPDATE_URL)
            .then(res => {
                if (!res.ok) throw new Error('HTTP ' + res.status);
                return res.text();
            })
            .then(script => {
                const match = script.match(versionRegex);
                if (!match) return;
                const remote = match[1];
                if (remote === PLUGIN_VERSION) return;

                console.log(`[${PLUGIN_NAME}] Update available: ${PLUGIN_VERSION} → ${remote}`);

                // Inject into #plugin-settings (standard fm-dx-webserver update notice location)
                const pluginSettings = document.getElementById('plugin-settings');
                if (pluginSettings) {
                    const newText = `<a href="${PLUGIN_HOMEPAGE_URL}" target="_blank">[${PLUGIN_NAME}] Update available: ${PLUGIN_VERSION} --> ${remote}</a><br>`;
                    if (pluginSettings.textContent.trim() === 'No plugin settings are available.') {
                        pluginSettings.innerHTML = newText;
                    } else {
                        pluginSettings.innerHTML += ' ' + newText;
                    }
                }

                // Red dot on the puzzle-piece nav icon (standard location)
                const navIcon =
                    document.querySelector('.wrapper-outer #navigation .sidenav-content .fa-puzzle-piece') ||
                    document.querySelector('.wrapper-outer .sidenav-content') ||
                    document.querySelector('.sidenav-content');
                if (navIcon) {
                    const redDot = document.createElement('span');
                    redDot.style.cssText = 'display:block; width:12px; height:12px; border-radius:50%; background-color:#FE0830; margin-left:82px; margin-top:-12px;';
                    navIcon.appendChild(redDot);
                }
            })
            .catch(() => {});
    }

    if (CHECK_FOR_UPDATES) checkForUpdate();

    // Wait for the DOM to be ready, then poll briefly for the heading
    // (setup page content may render slightly after DOMContentLoaded)
    function waitAndInject() {
        let attempts = 0;
        const interval = setInterval(() => {
            attempts++;
            injectButton();
            if (document.getElementById('pm2restart-panel') || attempts > 20) {
                clearInterval(interval);
            }
        }, 300);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', waitAndInject);
    } else {
        waitAndInject();
    }
})();
