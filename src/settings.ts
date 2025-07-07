import { Store } from '@tauri-apps/plugin-store';
export interface AppSettings {
  penWidth: number;
  arrowHeadLength: number;
  launchOnStartup: boolean;
  showExperimentalFeatures: boolean;
  breakTime: number;
  penColor?: string; // Optional, can be added later
  versionCheck?: boolean; // Optional, can be added later
  lastVersionCheck?: string; // Optional, can be added later
  shortcuts?: {
    drawing: string;
    text: string;
    break_mode: string;
    screenshot: string;
    preferences: string; // Default shortcut for preferences
  };
}

const defaultSettings: AppSettings = {
  penWidth: 3,
  arrowHeadLength: 20,
  launchOnStartup: false,
  showExperimentalFeatures: false,
  breakTime: 10, // default to 10 minutes
  penColor: '#ff0000', // Default pen color (red)
  versionCheck: true, // Default to true for version checks
  lastVersionCheck: '0',
  shortcuts: {
    drawing: 'Option+Shift+D',
    text: 'Option+Shift+T',
    break_mode: 'Option+Shift+B',
    screenshot: 'Option+Shift+S',
    preferences: 'Option+Shift+P' // Default shortcut for preferences
  }
};

let store: Store;

export async function initSettings(): Promise<AppSettings> {
  store = await Store.load('.settings.dat');
  // Load existing settings or create with defaults
  const settings = await store.get<AppSettings>('settings') || defaultSettings;
  await store.set('settings', settings);
  await store.save();

  return settings;
}

export async function getSettings(): Promise<AppSettings> {
  if (!store) {
    return await initSettings();
  }
  return await store.get<AppSettings>('settings') || defaultSettings;
}

export async function updateSetting<K extends keyof AppSettings>( key: K, value: AppSettings[K]): Promise<void> {
  const settings = await getSettings();
  settings[key] = value;
  await store.set('settings', settings);
  await store.save();
}

export async function resetSettings(): Promise<AppSettings> {
  await store.set('settings', defaultSettings);
  await store.save();
  return defaultSettings;
}