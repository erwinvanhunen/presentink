const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('electronAPI', {
  closeBreakTimer: () => ipcRenderer.send('close-break-timer'),
  getSettings: () => ipcRenderer.invoke('get-settings'),
});