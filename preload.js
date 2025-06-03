const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  onSetMode: (callback) => ipcRenderer.on('set-mode', (event, mode) => callback(event, mode)),
  onClearDrawing: (callback) => ipcRenderer.on('clear-drawing', (event) => callback(event)),
  onSetColor: (callback) => ipcRenderer.on('change-color', (event, color) => callback(event, color)),
  onShiftToggle: (callback) => ipcRenderer.on('shift-toggle', (event) => callback(event)),
  onUndo: (callback) => ipcRenderer.on('undo', (event) => callback(event)),
  onClearUndo: (callback) => ipcRenderer.on('clear-undo', (event) => callback(event)),
  saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
  exitDrawing: () => ipcRenderer.send('exit-drawing')
});