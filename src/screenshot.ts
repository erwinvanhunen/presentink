import { invoke } from "@tauri-apps/api/core";
import { save } from "@tauri-apps/plugin-dialog";

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
let factor: number;
let shiftPressed = false;
let lastX = 0, lastY = 0;

const floppySVG = `
      <svg width="16" height="16" viewBox="0 0 16 16" style="vertical-align:middle;margin-right:4px" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
        <rect x="2" y="2" width="12" height="12" rx="2" fill="#9ccc00" stroke="#1976d2" stroke-width="1"/>
        <rect x="4" y="4" width="8" height="5" fill="#fff" stroke="#1976d2" stroke-width="0.5"/>
        <rect x="6" y="10" width="4" height="2" fill="#1976d2"/>
        <rect x="10" y="2" width="2" height="4" fill="#90caf9"/>
      </svg>
    `;

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
    document.addEventListener('keydown', handleKeydown);
    document.addEventListener('keyup', handleKeyup);
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
    lastX = event.clientX;
    lastY = event.clientY;
    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);

    let coordX = currentX;
    let coordY = currentY;
    if (isSelecting) {
        coordX = width;
        coordY = height;
    }
    if (event.shiftKey) {
        coords.innerHTML = `(${Math.round(coordX)},${Math.round(coordY)}) ${floppySVG}`;
    } else {
        coords.textContent = `(${Math.round(coordX)},${Math.round(coordY)})`;
    }
    if(currentX > startX) {
        coords.style.left = currentX + 5 + 'px';
    } else {
        const coordsRect = coords.getBoundingClientRect();
        coords.style.left = currentX - coordsRect.width - 5 + 'px';
    }
    coords.style.top = currentY + 5 + 'px';

    var rect = instructions.getBoundingClientRect();

    if (currentX > rect.left && currentX < rect.right && currentY > rect.top && currentY < rect.bottom) {
        instructions.style.opacity = '0.3';
    } else {
        instructions.style.opacity = '1';
    }
    if (isSelecting) {
        const selRect = {
            left: left,
            right: left + width,
            top: top,
            bottom: top + height
        };

        // Check if selection rectangle and instructions rectangle overlap
        const overlap =
            selRect.left < rect.right &&
            selRect.right > rect.left &&
            selRect.top < rect.bottom &&
            selRect.bottom > rect.top;

        if (overlap) {
            instructions.style.opacity = '0';
        } else {
            instructions.style.opacity = '1';
        }
        selectionBox.style.left = left + 'px';
        selectionBox.style.top = top + 'px';
        selectionBox.style.width = width + 'px';
        selectionBox.style.height = height + 'px';

        topBox.style.left = '0px';
        topBox.style.top = '0px';
        topBox.style.height = top + 'px';
        topBox.style.width = '100%';

        bottomBox.style.left = '0px';
        bottomBox.style.top = top + height + 4 + 'px';
        bottomBox.style.height = window.innerHeight - top - height + 'px';
        bottomBox.style.width = '100%';

        leftBox.style.left = '0px';
        leftBox.style.top = top + 'px';
        leftBox.style.height = height + 4 + 'px';
        leftBox.style.width = left + 'px';

        rightBox.style.left = left + width + 4 + 'px';
        rightBox.style.top = top + 'px';
        rightBox.style.height = height + 4 + 'px';
        rightBox.style.width = window.innerWidth - left - width - 4 + 'px';
    }
}

async function endSelection(event: MouseEvent) {
    if (!isSelecting) return;

    isSelecting = false;
    const shiftPressed = event.shiftKey;

    const currentX = event.clientX;
    const currentY = event.clientY;


    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);

    if (width > 1 && height > 1) {
        const area = {
            x: Math.round(left),
            y: Math.round(top),
            width: Math.round(width),
            height: Math.round(height)
        };
        let selectedPath: string = "***";
        if (shiftPressed) {
            const path = await save({
                title: "Save Screenshot",
                defaultPath: `screenshot-${monitor}-${Date.now()}.png`,
                filters: [
                    {
                        name: 'PNG image}',
                        extensions: ['png'],
                    },
                ],
            });
            if (path === null) {
                invoke('close_screenshot_windows');
            }
            selectedPath = path || "";
            invoke("take_region_screenshot", { index: monitor, x: area.x + 2, y: area.y + 2, width: area.width, height: area.height, save: true, path: selectedPath });

        } else {
            invoke("take_region_screenshot", { index: monitor, x: area.x + 2, y: area.y + 2, width: area.width, height: area.height, save: false, path: "" });
        }
    }
}

function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Shift') {
        shiftPressed = true;
        updateCoordsDisplay();
    }
    if (event.key === 'Escape') {
        invoke("close_screenshot_window");
    }
}

function handleKeyup(event: KeyboardEvent) {
    if (event.key === 'Shift') {
        shiftPressed = false;
        updateCoordsDisplay();
    }
}

function updateCoordsDisplay() {
    if (!coords) return;
    const text = `(${Math.round(lastX)},${Math.round(lastY)})`;

    if (shiftPressed) {
        coords.innerHTML = `${text} ${floppySVG}`;
    } else {
        coords.textContent = text;
    }
}