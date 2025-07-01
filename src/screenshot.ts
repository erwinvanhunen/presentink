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
// let instructions: HTMLElement;
let saveButton: HTMLElement;
let closeButton: HTMLElement;
let clipboardButton: HTMLElement;
let toolbar: HTMLElement;
let monitor = "";
let factor: number;
let isDragging = false;
let dragStartX = 0;
let dragStartY = 0;
let selectionStartX = 0;
let selectionStartY = 0;
let isResizing = false;
let resizeHandle = '';
let resizeStartX = 0;
let resizeStartY = 0;
let originalRect = { left: 0, top: 0, width: 0, height: 0 };

window.addEventListener('DOMContentLoaded', async () => {
    selectionBox = document.getElementById('selectionBox')!;
    topBox = document.getElementById('topBox')!;
    bottomBox = document.getElementById('bottomBox')!;
    leftBox = document.getElementById('leftBox')!;
    rightBox = document.getElementById('rightBox')!;
    coords = document.getElementById('coords')!;
    toolbar = document.getElementById('toolbar')!;
    saveButton = document.getElementById('saveButton')!;
    closeButton = document.getElementById('closeButton')!;
    clipboardButton = document.getElementById('clipboardButton')!;
    saveButton.addEventListener('click', saveScreenshot);
    clipboardButton.addEventListener('click', copyScreenshot);
    closeButton.addEventListener('click', () => {
        invoke("close_screenshot_windows");
    });
    saveButton.addEventListener('mousedown', preventSelection);
    clipboardButton.addEventListener('mousedown', preventSelection);
    closeButton.addEventListener('mousedown', preventSelection);
    document.addEventListener('mousedown', startSelection);
    document.addEventListener('mousemove', updateSelection);
    document.addEventListener('mouseup', endSelection);
    document.addEventListener('keydown', handleKeydown);
    selectionBox.addEventListener('mousedown', startDrag);
    monitor = window.monitor.index;
    factor = window.monitor.factor;

    document.body.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
   
    createResizeHandles();
});

function preventSelection(event: MouseEvent) {
    event.stopPropagation();
    event.preventDefault();
}

function startSelection(event: MouseEvent) {
    const target = event.target as HTMLElement;
    if (target.closest('#selectionBox') || target.closest('#toolbar')) {
        return;
    }

    isSelecting = true;
    startX = event.clientX;
    startY = event.clientY;
    toolbar.style.display = 'none';
    selectionBox.style.left = startX + 'px';
    selectionBox.style.top = startY + 'px';
    selectionBox.style.width = '0px';
    selectionBox.style.height = '0px';
    selectionBox.style.display = 'block';

    document.body.style.backgroundColor = 'rgba(0, 0, 0, 0)';
    updateOverlayBoxes(event.clientX, event.clientY, 0, 0);

}


function startDrag(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    isDragging = true;
    dragStartX = event.clientX;
    dragStartY = event.clientY;

    // Store current selection position
    const rect = selectionBox.getBoundingClientRect();
    selectionStartX = rect.left;
    selectionStartY = rect.top;

    // Change cursor to indicate dragging
    document.body.style.cursor = 'move';
    selectionBox.style.cursor = 'move';

    // Hide toolbar while dragging
    toolbar.style.display = 'none';
}

function updateSelection(event: MouseEvent) {

    if (isResizing) {
        handleResize(event);
        return;
    }


    if (isDragging) {
        // Handle dragging
        const deltaX = event.clientX - dragStartX;
        const deltaY = event.clientY - dragStartY;

        let newLeft = selectionStartX + deltaX;
        let newTop = selectionStartY + deltaY;

        const rect = selectionBox.getBoundingClientRect();
        const width = rect.width;
        const height = rect.height;

        // Keep selection within screen bounds
        newLeft = Math.max(0, Math.min(newLeft, window.innerWidth - width));
        newTop = Math.max(0, Math.min(newTop, window.innerHeight - height));

        // Update selection box position
        selectionBox.style.left = newLeft + 'px';
        selectionBox.style.top = newTop + 'px';

        // Update overlay boxes
        updateOverlayBoxes(newLeft, newTop, width - 2, height - 2);

        return;
    }

    const currentX = event.clientX;
    const currentY = event.clientY;

    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);

    const toolbarRect = toolbar.getBoundingClientRect();
    const selectionRect = selectionBox.getBoundingClientRect();

    const isOverToolbar = currentX >= toolbarRect.left && currentX <= toolbarRect.right &&
        currentY >= toolbarRect.top && currentY <= toolbarRect.bottom;
    const isOverSelection = currentX >= selectionRect.left && currentX <= selectionRect.right &&
        currentY >= selectionRect.top && currentY <= selectionRect.bottom;

    // Only show coordinates if not over toolbar or selection box
    if (!isOverToolbar && !isOverSelection) {
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

    // var rect = instructions.getBoundingClientRect();


    if (isSelecting) {
        // const selRect = {
        //     left: left,
        //     right: left + width,
        //     top: top,
        //     bottom: top + height
        // };

        selectionBox.style.left = left + 'px';
        selectionBox.style.top = top + 'px';
        selectionBox.style.width = width + 'px';
        selectionBox.style.height = height + 'px';

        updateOverlayBoxes(left, top, width, height);
    }
}

function handleResize(event: MouseEvent) {
    const deltaX = event.clientX - resizeStartX;
    const deltaY = event.clientY - resizeStartY;

    let newLeft = originalRect.left;
    let newTop = originalRect.top;
    let newWidth = originalRect.width;
    let newHeight = originalRect.height;

    // Calculate new dimensions based on resize handle
    switch (resizeHandle) {
        case 'nw':
            newLeft += deltaX;
            newTop += deltaY;
            newWidth -= deltaX;
            newHeight -= deltaY;
            break;
        case 'n':
            newTop += deltaY;
            newHeight -= deltaY;
            break;
        case 'ne':
            newTop += deltaY;
            newWidth += deltaX;
            newHeight -= deltaY;
            break;
        case 'e':
            newWidth += deltaX;
            break;
        case 'se':
            newWidth += deltaX;
            newHeight += deltaY;
            break;
        case 's':
            newHeight += deltaY;
            break;
        case 'sw':
            newLeft += deltaX;
            newWidth -= deltaX;
            newHeight += deltaY;
            break;
        case 'w':
            newLeft += deltaX;
            newWidth -= deltaX;
            break;
    }

    // Enforce minimum size
    const minSize = 20;
    if (newWidth < minSize) {
        if (resizeHandle.includes('w')) {
            newLeft = originalRect.left + originalRect.width - minSize;
        }
        newWidth = minSize;
    }
    if (newHeight < minSize) {
        if (resizeHandle.includes('n')) {
            newTop = originalRect.top + originalRect.height - minSize;
        }
        newHeight = minSize;
    }

    // Keep within screen bounds
    newLeft = Math.max(0, newLeft);
    newTop = Math.max(0, newTop);
    newWidth = Math.min(newWidth, window.innerWidth - newLeft);
    newHeight = Math.min(newHeight, window.innerHeight - newTop);

    // Apply new dimensions
    selectionBox.style.left = newLeft + 'px';
    selectionBox.style.top = newTop + 'px';
    selectionBox.style.width = newWidth - 2 + 'px';
    selectionBox.style.height = newHeight - 2 + 'px';

    // Update overlay boxes
    updateOverlayBoxes(newLeft, newTop, newWidth - 2, newHeight - 2);
}

function updateOverlayBoxes(left: number, top: number, width: number, height: number) {
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

async function endSelection(event: MouseEvent) {

    if (isResizing) {
        // End resizing
        isResizing = false;
        document.body.style.cursor = 'crosshair';

        // Show toolbar again
        positionToolbar();
        toolbar.style.display = 'block';
        return;
    }

    if (isDragging) {
        // End dragging
        isDragging = false;
        document.body.style.cursor = 'crosshair';
        selectionBox.style.cursor = 'move';

        // Show toolbar again
        positionToolbar();
        toolbar.style.display = 'block';
        return;
    }

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
    hideHandles();
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
        invoke("close_screenshot_windows");
    }
}

function createResizeHandles() {
    const handles = ['nw', 'n', 'ne', 'e', 'se', 's', 'sw', 'w'];

    handles.forEach(direction => {
        const handle = document.createElement('div');
        handle.className = `resize-handle resize-${direction}`;
        handle.dataset.direction = direction;
        handle.addEventListener('mousedown', startResize);
        selectionBox.appendChild(handle);
    });
}

function hideHandles() {
    const handles = document.getElementsByClassName('resize-handle');
    for (let i = 0; i < handles.length; i++) {
        const handle = handles[i] as HTMLElement;
        handle.style.display = 'none';
    }
}

function startResize(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    isResizing = true;
    resizeHandle = (event.target as HTMLElement).dataset.direction || '';
    resizeStartX = event.clientX;
    resizeStartY = event.clientY;

    const rect = selectionBox.getBoundingClientRect();
    originalRect = {
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height
    };

    // Hide toolbar while resizing
    toolbar.style.display = 'none';

    // Change cursor based on resize direction
    document.body.style.cursor = getResizeCursor(resizeHandle);
}

function getResizeCursor(direction: string): string {
    const cursors: { [key: string]: string } = {
        'nw': 'nw-resize',
        'n': 'n-resize',
        'ne': 'ne-resize',
        'e': 'e-resize',
        'se': 'se-resize',
        's': 's-resize',
        'sw': 'sw-resize',
        'w': 'w-resize'
    };
    return cursors[direction] || 'default';
}