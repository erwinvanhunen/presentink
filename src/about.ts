import { invoke } from "@tauri-apps/api/core";


window.addEventListener('DOMContentLoaded', async () => {
    const version = await invoke('get_version') as string;

    const versionElement = document.getElementById('version') as HTMLSpanElement;
    if (versionElement) {
        versionElement.textContent = version;
    }

    const donateButton = document.getElementById('donateBtn') as HTMLButtonElement;
    donateButton.onclick = () => {
        invoke(('open_url'), { url: 'https://github.com/sponsors/erwinvanhunen' });
    };
});

