import { invoke } from "@tauri-apps/api/core";

declare global {
    interface Window {
        monitor: Monitor;
    }

    interface Monitor {
        index: string;
        factor: number;
    }
}

let isSelecting = false;
let startX = 0;
let startY = 0;
let selectionBox: HTMLElement;
let topBox: HTMLElement;
let bottomBox: HTMLElement;
let leftBox: HTMLElement;
let rightBox: HTMLElement;
let coords: HTMLElement;
let instructions: HTMLElement;
// let selectedMonitor = window.monitor; // Default monitor
let monitor = "";
let factor : number;

window.addEventListener('DOMContentLoaded', async () => {
    selectionBox = document.getElementById('selectionBox')!;
    topBox = document.getElementById('topBox')!;
    bottomBox = document.getElementById('bottomBox')!;
    leftBox = document.getElementById('leftBox')!;
    rightBox = document.getElementById('rightBox')!;
    coords = document.getElementById('coords')!;
    instructions = document.getElementById('instructions')!;
    document.addEventListener('mousedown', startSelection);
    document.addEventListener('mousemove', updateSelection);
    document.addEventListener('mouseup', endSelection);
    document.addEventListener('keydown', handleKeydown)
    monitor = window.monitor.index;
    factor = window.monitor.factor;
    instructions.style.top = 20 * factor + 'px';
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

    const currentX = event.clientX;
    const currentY = event.clientY;

    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);

    coords.style.top = currentY + 5 + 'px';
    coords.style.left = currentX + 5 + 'px';
    if (!isSelecting) {
        coords.textContent = `(${Math.round(currentX)},${Math.round(currentY)})`;
    } else {
        coords.textContent = `(${Math.round(width)},${Math.round(height)})`;
        selectionBox.style.left = left + 'px';
        selectionBox.style.top = top + 'px';
        selectionBox.style.width = width + 'px';
        selectionBox.style.height = height + 'px';

        topBox.style.left = '0px';
        topBox.style.top = '0px';
        topBox.style.height = top + 'px';
        topBox.style.width = '100%';
        bottomBox.style.left = '0px';
        bottomBox.style.top = top + height + 2 + 'px';
        bottomBox.style.height = window.innerHeight - top - height - 2 + 'px';
        bottomBox.style.width = '100%';

        leftBox.style.left = '0px';
        leftBox.style.top = top + 'px';
        leftBox.style.height = height + 2 + 'px';
        leftBox.style.width = left + 'px';

        rightBox.style.left = left + width + 2 + 'px';
        rightBox.style.top = top + 'px';
        rightBox.style.height = height + 2 + 'px';
        rightBox.style.width = window.innerWidth - left - width + 'px';
    }
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

    if (width > 1 && height > 1) { // Minimum selection size
        const area = {
            x: Math.round(left),
            y: Math.round(top),
            width: Math.round(width),
            height: Math.round(height)
        };
        // selectionBox.style.visibility = 'hidden'; // Hide the selection box

        invoke("take_region_screenshot", { index: monitor, x: area.x + 2, y: area.y + 2, width: area.width, height: area.height });
    }
}

function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
        invoke("close_screenshot_window");
    }
}