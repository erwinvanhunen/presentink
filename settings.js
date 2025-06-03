// settings.js
const fs = require('fs');
const path = require('path');

const appName = 'PresentInk'; // Change as needed

function getSettingsPath() {
  let base;
  if (process.platform === 'darwin') {
    base = path.join(process.env.HOME, 'Library', 'Application Support', appName);
  } else if (process.platform === 'win32') {
    base = path.join(process.env.APPDATA, appName);
  } else {
    base = path.join(process.env.HOME, `.${appName.toLowerCase()}`);
  }
  if (!fs.existsSync(base)) fs.mkdirSync(base, { recursive: true });
  return path.join(base, 'settings.json');
}

const settingsPath = getSettingsPath();

const defaultSettings = {
   breakTime : 10,
   showBorder: true
  // Add other defaults as needed
};

function loadSettings() {
  try {
    const raw = fs.readFileSync(settingsPath, 'utf8');
    return { ...defaultSettings, ...JSON.parse(raw) };
  } catch (err) {
    console.log(err.message);
    return { ...defaultSettings };
  }
}

function saveSettings(newSettings) {
  const current = loadSettings();
  const merged = { ...current, ...newSettings };
  fs.writeFileSync(settingsPath, JSON.stringify(merged, null, 2), 'utf8');
  return merged;
}

module.exports = { loadSettings, saveSettings, settingsPath };
