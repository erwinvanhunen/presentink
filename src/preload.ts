// const { contextBridge, ipcRenderer } = require('electron');
import { contextBridge, ipcRenderer } from 'electron';

// interface ElectronAPI {
//   onSetMode: (callback: (event: Electron.IpcRendererEvent, mode: any) => void) => void;
//   onClearDrawing: (callback: (event: Electron.IpcRendererEvent) => void) => void;
//   onSetColor: (callback: (event: Electron.IpcRendererEvent, color: any) => void) => void;
//   onShiftToggle: (callback: (event: Electron.IpcRendererEvent) => void) => void;
//   onUndo: (callback: (event: Electron.IpcRendererEvent) => void) => void;
//   onClearUndo: (callback: (event: Electron.IpcRendererEvent) => void) => void;
//   // saveSettings: (settings: any) => void;
//   updateSettings: (callback: (event: Electron.IpcRendererEvent, settings: any) => void) => void;
//   exitDrawing: () => void;
//   getSettings: () => Promise<any>;
//   saveSettings: (settings: any) => void;
//   openDonate: (url: string) => Promise<any>;
//   writeLog: (message: string) => Promise<void>;
// }

contextBridge.exposeInMainWorld('electronAPI', {
  onSetMode: (callback: (event: Electron.IpcRendererEvent, mode: any) => void) => ipcRenderer.on('set-mode', (event, mode) => callback(event, mode)),
  onClearDrawing: (callback: (event: Electron.IpcRendererEvent) => void) => ipcRenderer.on('clear-drawing', (event) => callback(event)),
  onSetColor: (callback: (event: Electron.IpcRendererEvent, color: any) => void) => ipcRenderer.on('change-color', (event, color) => callback(event, color)),
  onShiftToggle: (callback: (event: Electron.IpcRendererEvent) => void) => ipcRenderer.on('shift-toggle', (event) => callback(event)),
  onUndo: (callback: (event: Electron.IpcRendererEvent) => void) => ipcRenderer.on('undo', (event) => callback(event)),
  onClearUndo: (callback: (event: Electron.IpcRendererEvent) => void) => ipcRenderer.on('clear-undo', (event) => callback(event)),
  // saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
  updateSettings: (callback: (event: Electron.IpcRendererEvent, settings: any) => void) => ipcRenderer.on('update-settings', (event, settings) => callback(event, settings)),
  exitDrawing: (): void => ipcRenderer.send('exit-drawing'),
  getSettings: (): Promise<any> => ipcRenderer.invoke('get-settings'),
  saveSettings: (settings: any): void => ipcRenderer.send('save-settings', settings),
  openDonate: (url: string): Promise<any> => ipcRenderer.invoke('open-donate', url),
  writeLog(message: string): Promise<void> { return ipcRenderer.invoke('write-log', message); },
  onWindowFocused: (callback: (event: Electron.IpcRendererEvent) => void) => ipcRenderer.on('window-focused', (event) => callback(event)),
  onWindowShown: (callback: (event: Electron.IpcRendererEvent) => void) => ipcRenderer.on('window-shown', (event) => callback(event)),
  setLaunchAtLogin: (enabled: boolean): Promise<void> => ipcRenderer.invoke('set-launch-at-login', enabled),
});


// declare global {
//   interface Window {
//     electronAPI: ElectronAPI;
//   }
// }