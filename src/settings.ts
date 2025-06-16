import * as path from 'path'
import fs from 'fs';

const appName = 'PresentInk'; // Change as needed


export function getSettingsPath() {
  let base;
  if (process.platform === 'darwin') {
    const home = process.env.HOME;
    if (!home) throw new Error('HOME environment variable is not set');
    base = path.join(home, 'Library', 'Application Support', appName);
  } else if (process.platform === 'win32') {
    const appData = process.env.APPDATA;
    if (!appData) throw new Error('APPDATA environment variable is not set');
    base = path.join(appData, appName);
  } else {
    const home = process.env.HOME;
    if (!home) throw new Error('HOME environment variable is not set');
    base = path.join(home, `.${appName.toLowerCase()}`);
  }
  if (!fs.existsSync(base)) fs.mkdirSync(base, { recursive: true });
  return path.join(base, 'settings.json');
}

const settingsPath = getSettingsPath();

const defaultSettings: Settings = {
  breakTime: 10,
  penWidth: 3,
  arrowHead: 20,
  launchOnStartup: false
};

export function loadSettings(): Settings {
  try {
    const raw = fs.readFileSync(settingsPath, 'utf8');
    return { ...defaultSettings, ...JSON.parse(raw) };
  } catch (err) {
    if (err instanceof Error) {
      console.log(err.message);
    } else {
      console.log(String(err));
    }
    return { ...defaultSettings };
  }
}

export function saveSettings(newSettings: Partial<Settings>) {
  const current = loadSettings();
  const merged = { ...current, ...newSettings };
  fs.writeFileSync(settingsPath, JSON.stringify(merged, null, 2), 'utf8');
  return merged;
}