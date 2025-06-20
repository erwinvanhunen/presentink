
import { getSettings } from './settings';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { invoke } from '@tauri-apps/api/core';

let timeLeft = 10 * 60; // default to 30 minutes in seconds
let timerElem: HTMLSpanElement;
let interval: number | null = null;

window.addEventListener('DOMContentLoaded', async () => {
    const appSettings = await getSettings();
    if (appSettings.breakTime) {
        timerElem = document.getElementById('timer') as HTMLSpanElement;
        timeLeft = appSettings.breakTime * 60;
        invoke("print_output", { text: `Break timer started for ${appSettings.breakTime} minutes.` });
        timerElem.style.visibility = 'visible';
        updateDisplay();
        interval = setInterval(() => {
            timeLeft--;
            if (timeLeft <= 0) {
                if (interval) clearInterval(interval);
                window.close();
            }
            updateDisplay();
        }, 1000);

        document.addEventListener('keydown', async (e) => {
            e.preventDefault();
            if (interval) {
                clearInterval(interval);
                interval = null;
            }
            await invoke('close_breaktimer');
            await closeWindow();
        });

        document.addEventListener('click', async (e) => {
            e.preventDefault();
            if (interval) {
                clearInterval(interval);
                interval = null;
            }
            await invoke('close_breaktimer');
            await closeWindow();
        });
    } else {
        console.error("Break time setting not found. Please check your settings.");
        timerElem = document.getElementById('timer') as HTMLSpanElement;
        timerElem.textContent = "00:00";
        timerElem.style.visibility = 'hidden';
    }
});

function updateDisplay() {
    const min = Math.floor(timeLeft / 60).toString().padStart(2, '0');
    const sec = (timeLeft % 60).toString().padStart(2, '0');
    timerElem.textContent = `${min}:${sec}`;
}

async function closeWindow() {
    try {
        const window = getCurrentWindow();
        await window.close();
    } catch (error) {
        console.error("Failed to close window:", error);
        // Fallback to the old method
        window.close();
    }
}