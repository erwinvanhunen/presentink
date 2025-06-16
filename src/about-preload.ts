import { contextBridge, ipcRenderer } from 'electron';
contextBridge.exposeInMainWorld('electronAPI', {
    getVersion: () => ipcRenderer.invoke('get-version'),
    openDonate: (url: string) => ipcRenderer.invoke('open-donate', url),
    setVersion: (version: string) => ipcRenderer.send('set-version', version),
});

window.addEventListener('DOMContentLoaded', () => {
    ipcRenderer.on('set-version', (event :any, version: string) => {
        const versionDiv = document.getElementById('version');
        if (versionDiv) versionDiv.textContent = 'Version ' + version;
    });
});