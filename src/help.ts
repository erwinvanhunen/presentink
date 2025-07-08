import { invoke } from "@tauri-apps/api/core";


window.addEventListener('DOMContentLoaded', async () => {
    const donateButton = document.getElementById('donateBtn') as HTMLButtonElement;
    donateButton.onclick = () => {
        invoke(('open_url'), { url: 'https://github.com/sponsors/erwinvanhunen' });
    };
});

window.addEventListener('contextmenu', (e) => {
  e.preventDefault();
});