const { contextBridge, ipcRenderer, shell } = require('electron');
contextBridge.exposeInMainWorld('electronAPI', {
    getVersion: () => ipcRenderer.invoke('get-version'),
    openDonate: (url) => ipcRenderer.invoke('open-donate', url),
});
