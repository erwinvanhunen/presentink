import { invoke } from '@tauri-apps/api/core';
import { AppSettings } from './settings';

async function loadShortcut() {
    try {
      
        // Get settings from backend
        let settings = await invoke("get_settings") as AppSettings
        const drawingShortcut = settings.shortcuts?.drawing || 'Option+Shift+D';
        // Parse the shortcut string and format it nicely
        const keys = drawingShortcut.split('+').map(key => key.trim());
        const formattedKeys = keys.map(key => `<kbd>${key}</kbd>`).join(' + ');

        // Update the display
        const shortcutElement = document.getElementById('shortcut-keys');
        if (shortcutElement) {
            shortcutElement.innerHTML = formattedKeys;
        }
    } catch (error) {
        //console.error('Failed to load shortcut:', error);
    }
}

document.addEventListener('DOMContentLoaded', async () => {

    await loadShortcut();

    const intro = document.getElementById('app-intro');
    if (intro) {
        setTimeout(() => {
            intro.classList.add('visible');
        }, 10); // allow DOM to render

        
        setTimeout(() => {
            intro.classList.remove('visible');
        }, 1500);


        setTimeout(() => {
            intro.style.display = 'none';
        }, 3000);
    }
});