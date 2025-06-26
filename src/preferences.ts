import { getSettings, updateSetting, AppSettings } from './settings';
import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from '@tauri-apps/api/window';

let appSettings: AppSettings;
let penWidthInt = 3;
let arrowHeadLengthInt = 20;
window.addEventListener('DOMContentLoaded', async () => {
    appSettings = await getSettings();
    setupEventListeners();
    updateUI();
});

function setupEventListeners() {
    const currentWindow = getCurrentWindow();
    const penWidthCanvas = document.getElementById('dotPreview') as HTMLCanvasElement
    const penWidthCtx = penWidthCanvas?.getContext('2d');
    const arrowCanvas = document.getElementById('arrowPreview') as HTMLCanvasElement;
    const arrowCtx = arrowCanvas?.getContext('2d');

    const penWidth = document.getElementById('penWidth') as HTMLInputElement;
    const penWidthValue = document.getElementById('penWidthValue') as HTMLSpanElement;
    const breakTime = document.getElementById('breakTime') as HTMLInputElement;
    const breakTimeValue = document.getElementById('breakTimeValue') as HTMLSpanElement;
    const arrowHead = document.getElementById('arrowHead') as HTMLInputElement;
    const arrowHeadValue = document.getElementById('arrowHeadValue');
    const launchAtLogin = document.getElementById('launchAtLogin') as HTMLInputElement
    const showExperimental = document.getElementById('showExperimental') as HTMLInputElement;

    const closeBtn = document.getElementById('closeBtn');
    if (closeBtn) {
        closeBtn.addEventListener('click', async () => {
            await currentWindow.close();
        });
    }
    
    document.addEventListener('keydown', async (e) => {
        if (e.key === 'Escape') {
            await currentWindow.close();
        }
    });

    if (arrowHead && arrowHeadValue && arrowCtx && arrowCanvas && penWidth && penWidthValue && penWidthCtx && penWidthCanvas) {
        arrowHead.oninput = () => {
            if (arrowHeadValue) arrowHeadValue.textContent = arrowHead.value;
            penWidthInt = parseInt(penWidth.value, 10) || 3; // Default to 3 if not a valid number
            arrowHeadLengthInt = parseInt(arrowHead.value, 10) || 20; // Default to 20 if not a valid number
            drawArrow(arrowCtx, arrowCanvas, 0, arrowCanvas.height / 2, arrowCanvas.width, arrowCanvas.height / 2, penWidthInt, arrowHeadLengthInt);
            updateSetting('arrowHeadLength', arrowHeadLengthInt);
        };
    }

    if (breakTime && breakTimeValue) {
        breakTime.oninput = () => {
            breakTimeValue.textContent = `${breakTime.value} min`;
            updateSetting('breakTime', parseInt(breakTime.value));

        };
    }

    if (penWidthCtx && penWidthCanvas && arrowCtx && arrowCanvas) {
        penWidth.oninput = () => {
            penWidthValue.textContent = penWidth.value;
            penWidthInt = parseInt(penWidth.value, 10) || 3; // Default to 3 if not a valid number
            drawPenWidth(penWidthCtx, penWidthCanvas, penWidthInt);
            drawArrow(arrowCtx, arrowCanvas, 0, arrowCanvas.height / 2, arrowCanvas.width, arrowCanvas.height / 2, penWidthInt, arrowHeadLengthInt);
            updateSetting('penWidth', penWidthInt);
        };
    }

    if (launchAtLogin) {
        launchAtLogin.onchange = async () => {
            updateSetting('launchOnStartup', launchAtLogin.checked);
            if (launchAtLogin.checked) {
                invoke('enable_autolaunch');
                // await enable(); 
            } else {
                invoke('disable_autolaunch');
            }
        };
    }

    if (showExperimental) {
        showExperimental.onchange = () => {
            updateSetting('showExperimentalFeatures', showExperimental.checked);
            invoke('update-settings', {
                'show-experimental-features': showExperimental.checked

            });
        };
    }


}

function drawPenWidth(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement, width: number) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = width;
    ctx.strokeStyle = '#ff0000'; // Example color
    ctx.moveTo(0, canvas.height / 2);
    ctx.lineTo(canvas.width, canvas.height / 2);
    ctx.stroke();
}

function drawArrow(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement, fromX: number, fromY: number, toX: number, toY: number, penWidth: number, arrowHeadLength: number) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const headlen = arrowHeadLength; // Arrowhead length
    const dx = toX - fromX;
    const dy = toY - fromY;
    const angle = Math.atan2(dy, dx);

    // Calculate endpoint of the shaft (before the arrowhead starts)
    const shaftX = toX - (headlen - 2) * Math.cos(angle);
    const shaftY = toY - (headlen - 2) * Math.sin(angle);

    // Draw shaft
    ctx.strokeStyle = "#ff0000"; // Use the selected stroke color
    ctx.lineWidth = penWidth;
    ctx.lineCap = 'square'
    ctx.beginPath();
    ctx.moveTo(fromX, fromY);
    ctx.lineTo(shaftX, shaftY);
    ctx.stroke();

    // Draw filled arrowhead 
    const arrowX1 = toX - headlen * Math.cos(angle - Math.PI / 7);
    const arrowY1 = toY - headlen * Math.sin(angle - Math.PI / 7);

    const arrowX2 = toX - headlen * Math.cos(angle + Math.PI / 7);
    const arrowY2 = toY - headlen * Math.sin(angle + Math.PI / 7);

    ctx.beginPath();
    ctx.moveTo(toX, toY);
    ctx.lineTo(arrowX1, arrowY1);
    ctx.lineTo(arrowX2, arrowY2);
    ctx.closePath();
    ctx.fillStyle = "#ff0000"; // Use the selected fill color
    ctx.fill();
}

function updateUI() {
    const penWidth = document.getElementById('penWidth') as HTMLInputElement;
    const penWidthValue = document.getElementById('penWidthValue') as HTMLSpanElement;
    const breakTime = document.getElementById('breakTime') as HTMLInputElement;
    const breakTimeValue = document.getElementById('breakTimeValue') as HTMLSpanElement;
    const arrowHead = document.getElementById('arrowHead') as HTMLInputElement;
    const arrowHeadValue = document.getElementById('arrowHeadValue');
    const launchAtLogin = document.getElementById('launchAtLogin') as HTMLInputElement
    const showExperimental = document.getElementById('showExperimental') as HTMLInputElement;

    penWidthInt = appSettings.penWidth || 3;
    arrowHeadLengthInt = appSettings.arrowHeadLength || 20;
    penWidth.value = penWidthInt.toString();
    penWidthValue.textContent = penWidthInt.toString();
    breakTime.value = appSettings.breakTime ? appSettings.breakTime.toString() : '30';
    breakTimeValue.textContent = `${breakTime.value} min`;
    arrowHead.value = arrowHeadLengthInt.toString();
    if (arrowHeadValue) arrowHeadValue.textContent = arrowHead.value;
    if (launchAtLogin) {
        launchAtLogin.checked = appSettings.launchOnStartup || false;
    }
    if (showExperimental) {
        showExperimental.checked = appSettings.showExperimentalFeatures || false;
    }
    const penWidthCanvas = document.getElementById('dotPreview') as HTMLCanvasElement;
    const penWidthCtx = penWidthCanvas?.getContext('2d');
    const arrowCanvas = document.getElementById('arrowPreview') as HTMLCanvasElement;
    const arrowCtx = arrowCanvas?.getContext('2d');
    if (penWidthCtx && penWidthCanvas) {
        drawPenWidth(penWidthCtx, penWidthCanvas, penWidthInt);
    }
    if (arrowCtx && arrowCanvas) {
        drawArrow(arrowCtx, arrowCanvas, 0, arrowCanvas.height / 2, arrowCanvas.width, arrowCanvas.height / 2, penWidthInt, arrowHeadLengthInt);
    }
}