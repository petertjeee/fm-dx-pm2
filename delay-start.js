// delay-start.js
// Delays the start of the main application by 20 seconds.
// Used by PM2 ecosystem config to ensure fm-dx-webserver is fully up
// before fm-dx-monitoring starts. Works on Linux, macOS and Windows.
setTimeout(() => { require('./index.js'); }, 20000);
