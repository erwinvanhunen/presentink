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
let saveButton: HTMLElement;
let closeButton: HTMLElement;
let clipboardButton: HTMLElement;
let toolbar: HTMLElement;
let monitor = "";
let factor: number;
let lastX = 0, lastY = 0;

window.addEventListener('DOMContentLoaded', async () => {
    selectionBox = document.getElementById('selectionBox')!;
    topBox = document.getElementById('topBox')!;
    bottomBox = document.getElementById('bottomBox')!;
    leftBox = document.getElementById('leftBox')!;
    rightBox = document.getElementById('rightBox')!;
    coords = document.getElementById('coords')!;
    instructions = document.getElementById('instructions')!;
    toolbar = document.getElementById('toolbar')!;
    saveButton = document.getElementById('saveButton')!;
    closeButton = document.getElementById('closeButton')!;
    clipboardButton = document.getElementById('clipboardButton')!;
    saveButton.addEventListener('click', saveScreenshot);
    clipboardButton.addEventListener('click', copyScreenshot);
    closeButton.addEventListener('click', () => {
        invoke("close_screenshot_window");
    });
    saveButton.addEventListener('mousedown', preventSelection);
    clipboardButton.addEventListener('mousedown', preventSelection);
    closeButton.addEventListener('mousedown', preventSelection);
    document.addEventListener('mousedown', startSelection);
    document.addEventListener('mousemove', updateSelection);
    document.addEventListener('mouseup', endSelection);
    document.addEventListener('keydown', handleKeydown);
    monitor = window.monitor.index;
    factor = window.monitor.factor;
    instructions.style.top = 20 * factor + 'px';
});

function preventSelection(event: MouseEvent) {
    event.stopPropagation();
    event.preventDefault();
}

function startSelection(event: MouseEvent) {
    isSelecting = true;
    startX = event.clientX;
    startY = event.clientY;
    toolbar.style.display = 'none';
    selectionBox.style.left = startX + 'px';
    selectionBox.style.top = startY + 'px';
    selectionBox.style.width = '0px';
    selectionBox.style.height = '0px';
    selectionBox.style.display = 'block';

    topBox.style.display = 'none';
    bottomBox.style.display = 'none';
    leftBox.style.display = 'none';
    rightBox.style.display = 'none';
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

    const toolbarRect = toolbar.getBoundingClientRect();
    if (currentX < toolbarRect.left || currentX > toolbarRect.right || currentY < toolbarRect.top || currentY > toolbarRect.bottom) {
        coords.style.display = 'block';
        let coordX = currentX;
        let coordY = currentY;
        if (isSelecting) {
            coordX = width;
            coordY = height;
        }
        coords.textContent = `(${Math.round(coordX)},${Math.round(coordY)})`;
        if (currentX > startX) {
            coords.style.left = currentX + 5 + 'px';
        } else {
            const coordsRect = coords.getBoundingClientRect();
            coords.style.left = currentX - coordsRect.width - 5 + 'px';
        }
        coords.style.top = currentY + 5 + 'px';
    } else {
        coords.style.display = 'none';
    }
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

        topBox.style.display = 'block';
        topBox.style.left = '0px';
        topBox.style.top = '0px';
        topBox.style.height = top + 'px';
        topBox.style.width = '100%';

        bottomBox.style.display = 'block';
        bottomBox.style.left = '0px';
        bottomBox.style.top = top + height + 4 + 'px';
        bottomBox.style.height = window.innerHeight - top - height + 'px';
        bottomBox.style.width = '100%';

        leftBox.style.display = 'block';
        leftBox.style.left = '0px';
        leftBox.style.top = top + 'px';
        leftBox.style.height = height + 4 + 'px';
        leftBox.style.width = left + 'px';

        rightBox.style.display = 'block';
        rightBox.style.left = left + width + 4 + 'px';
        rightBox.style.top = top + 'px';
        rightBox.style.height = height + 4 + 'px';
        rightBox.style.width = window.innerWidth - left - width - 4 + 'px';
    }
}

async function endSelection(event: MouseEvent) {
    if (!isSelecting) return;

    const currentX = event.clientX;
    const currentY = event.clientY;
    isSelecting = false;

    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);
    if (width > 5 && height > 5) {
        positionToolbar();
        toolbar.style.display = 'block';
    } else {
        selectionBox.style.display = 'none';
    }
}

function positionToolbar() {
    toolbar.style.display = 'block';
    toolbar.style.visibility = 'hidden';
    toolbar.style.position = 'absolute';
    toolbar.style.left = '-9999px';

    const selectionRect = selectionBox.getBoundingClientRect();
    const toolbarRect = toolbar.getBoundingClientRect();
    const toolbarWidth = toolbarRect.width;
    const toolbarHeight = toolbarRect.height;

    toolbar.style.visibility = 'visible';
    toolbar.style.position = 'fixed';
    toolbar.style.left = '0px'; // Will be set properly below

    // Calculate desired position (bottom right of selection)
    let toolbarLeft = selectionRect.x + selectionRect.width - toolbarWidth;
    let toolbarTop = selectionRect.top + selectionRect.height + 5; // 10px gap below selection

    // Check if toolbar fits on screen at bottom right
    const screenWidth = window.innerWidth;
    const screenHeight = window.innerHeight;

    // Adjust horizontal position if toolbar goes off screen
    if (toolbarLeft < 0) {
        toolbarLeft = selectionRect.x; // Align with left edge of selection
    }
    if (toolbarLeft + toolbarWidth > screenWidth) {
        toolbarLeft = screenWidth - toolbarWidth - 10; // 10px margin from right edge
    }

    // Check if toolbar fits vertically at bottom, otherwise position at top
    if (toolbarTop + toolbarHeight > screenHeight) {
        // Position above selection instead
        toolbarTop = selectionRect.top - toolbarHeight - 10; // 10px gap above selection

        // If still doesn't fit, position at top of screen
        if (toolbarTop < 0) {
            toolbarTop = 10; // 10px from top of screen
        }
    }

    // Apply positioning
    toolbar.style.position = 'fixed';
    toolbar.style.left = toolbarLeft + 'px';
    toolbar.style.top = toolbarTop + 'px';
    toolbar.style.transform = 'none'; // Remove the center transform
}

// Prevent default context me
async function copyScreenshot() {
    const area = selectionBox.getBoundingClientRect();
    invoke("take_region_screenshot", { index: monitor, x: area.x + 2, y: area.y + 2, width: area.width - 4, height: area.height - 4, save: false, path: "" });
}


// Prevent default context me
async function saveScreenshot() {
    // if (!isSelecting) return;
    const area = selectionBox.getBoundingClientRect();

    let selectedPath: string = "***";

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
    } else {
        selectedPath = path || "";
        document.body.style.backgroundColor = 'transparent';
        selectionBox.style.display = 'none';
        invoke("take_region_screenshot", { index: monitor, x: area.x + 2, y: area.y + 2, width: area.width - 4, height: area.height - 4, save: true, path: selectedPath });
    }
}

function handleKeydown(event: KeyboardEvent) {

    if (event.key === 'Escape') {
        invoke("close_screenshot_window");
    }
}
