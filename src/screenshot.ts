import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

declare global {
    interface Window {
        monitor: any;
    }
}

let isSelecting = false;
let startX = 0;
let startY = 0;
let selectionBox: HTMLElement;

let selectedMonitor = window.monitor; // Default monitor
let monitor = "";


window.addEventListener('DOMContentLoaded', async () => {
    selectionBox = document.getElementById('selectionBox')!;

    document.addEventListener('mousedown', startSelection);
    document.addEventListener('mousemove', updateSelection);
    document.addEventListener('mouseup', endSelection);
    document.addEventListener('keydown', handleKeydown);
    invoke("print_output", { text: selectedMonitor.index });
    monitor = selectedMonitor.index;
    // listen("set-monitor", () => {
    //     // monitor = event.payload as string;
    //     invoke("print_output", { text: `Monitor selected: ${selectedMonitor.name}` });
    // });
});

function startSelection(event: MouseEvent) {
    isSelecting = true;
    startX = event.clientX;
    startY = event.clientY;

    selectionBox.style.left = startX + 'px';
    selectionBox.style.top = startY + 'px';
    selectionBox.style.width = '0px';
    selectionBox.style.height = '0px';
    selectionBox.style.display = 'block';
}

function updateSelection(event: MouseEvent) {
    if (!isSelecting) return;

    const currentX = event.clientX;
    const currentY = event.clientY;

    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);

    selectionBox.style.left = left + 'px';
    selectionBox.style.top = top + 'px';
    selectionBox.style.width = width + 'px';
    selectionBox.style.height = height + 'px';
}

function endSelection(event: MouseEvent) {
    if (!isSelecting) return;

    isSelecting = false;

    const currentX = event.clientX;
    const currentY = event.clientY;

    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);

    if (width > 10 && height > 10) { // Minimum selection size
        const area = {
            x: Math.round(left * window.devicePixelRatio),
            y: Math.round(top * window.devicePixelRatio),
            width: Math.round(width * window.devicePixelRatio),
            height: Math.round(height * window.devicePixelRatio)
        };
        invoke("take_region_screenshot", { index: monitor, x: area.x, y: area.y, width: area.width, height: area.height });
        // window.electronAPI.screenshotAreaSelected(area);
    } else {
        // window.electronAPI.screenshotCancelled();
    }
}

function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
        // window.electronAPI.screenshotCancelled();
    }
}