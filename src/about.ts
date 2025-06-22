import { invoke } from "@tauri-apps/api/core";

window.addEventListener('DOMContentLoaded', async () => {
    // const version = await invoke('get_version') as string;
    const versionElement = document.getElementById('version') as HTMLSpanElement;
    if (versionElement) {
        (invoke('get_version') as Promise<string>).then((v: string) => {
            versionElement.textContent = v;
        }).catch((error) => {
            console.error("Error fetching version:", error);
            versionElement.textContent = "Unknown Version";
        });
        // versionElement.textContent = version;
    }

    const donateButton = document.getElementById('donateBtn') as HTMLButtonElement;
    donateButton.onclick = () => {
        invoke(('open_url'), { url: 'https://github.com/sponsors/erwinvanhunen' });
    };
});

