// import { appWindow, availableMonitors } from "@tauri-apps/api/window";
// import { setDockVisibility } from '@tauri-apps/api/app';
import { Window } from '@tauri-apps/api/window';
import { listen } from '@tauri-apps/api/event';
import { invoke } from "@tauri-apps/api/core";
import { getSettings, updateSetting, AppSettings } from './settings';

let undoStack: string[] = [];
const MAX_UNDO = 30; // Adjust for memory usage, if you want
const drawCanvas = document.getElementById('draw-canvas') as HTMLCanvasElement;
const ctx = drawCanvas.getContext('2d');
const previewCanvas = document.getElementById('preview-canvas') as HTMLCanvasElement;
const previewCtx = previewCanvas.getContext('2d');
const cursorCanvas = document.getElementById('cursor-canvas') as HTMLCanvasElement;
const cursorCtx = cursorCanvas.getContext('2d');

let appSettings: AppSettings;
let drawingMode = "freehand"; // Default drawing mode
let strokeColor = "#ff0000"; // Default stroke color
let drawing = false; // Flag to check if drawing is in progress
let startX = 0, startY = 0;
let prevX = 0, prevY = 0;
let lineStartX = 0, lineStartY = 0;
let mousePos = { x: 0, y: 0 };
let penWidth = 3; // Default pen width
let arrowHeadLength = 20; // Default arrow head length
let hasMouseMoved = false;

if (document.readyState === "loading") {
  window.addEventListener("DOMContentLoaded", initializeOverlay);
} else {
  await initializeOverlay();
}

async function initializeOverlay() {

  appSettings = await getSettings();
  penWidth = appSettings.penWidth;
  arrowHeadLength = appSettings.arrowHeadLength;

  const currentWindow = Window.getCurrent();

  currentWindow.setVisibleOnAllWorkspaces(true);

  await listen('start-drawing', async () => {
    appSettings = await getSettings();
    penWidth = appSettings.penWidth;
    arrowHeadLength = appSettings.arrowHeadLength;
    invoke('change_tray_icon', {
      color: strokeColor,
      isDrawing: true
    });
    toggleCanvas(true); // Show canvas
  });

  await listen('stop-drawing', () => {
    undoStack = []; // Clear undo stack
    toggleCanvas(false); // Hide canvas
  });

  await listen('change-color', (event) => {
    const color = event.payload as string;
    changeColor(color, false); // Change color without updating tray icon
  });
  window.addEventListener('mousemove', async () => {
    if (!hasMouseMoved) {
      hasMouseMoved = true;

      await currentWindow.setFocus();

      // Reset flag after a short delay
      setTimeout(() => {
        hasMouseMoved = false;
      }, 1000);
    }
  });

  // Also focus on mouse enter
  window.addEventListener('mouseenter', async () => {
    invoke('print_output', { text: `Mouse entered overlay` });
    await currentWindow.setFocus();
    await currentWindow.setAlwaysOnTop(true);
    drawCursor();
  });
  window.addEventListener('mouseover', async () => {
    await currentWindow.setFocus();
    await currentWindow.setAlwaysOnTop(true);
  });
  // await listen('settings-updated', async () => {
  //   appSettings = await getSettings();
  //   penWidth = appSettings.penWidth;
  //   arrowHeadLength = appSettings.arrowHeadLength;
  // });

}
function toggleCanvas(show: boolean): void {
  const window = Window.getCurrent();
  if (!show) {
    clearCanvas();
    window.hide();
    // invoke('print_output', { text: `window ${window.label} hidden` });
  } else {
    clearCanvas();
    window.show().then(() => {
      // invoke('print_output', { text: `window ${window.label} shown` });
      window.setFocus();
      window.setAlwaysOnTop(true);
    });
  }
}

function clearCanvas(): void {
  if (ctx) {
    ctx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
  }
}


function saveState() {
  if (undoStack.length >= MAX_UNDO) undoStack.shift(); // Limit history
  undoStack.push(drawCanvas.toDataURL());
}

function changeColor(color: string, setTrayIcon = false) {
  strokeColor = color;
  if (setTrayIcon) {
    // Update the cursor color
    console.log(`Changing color to: ${color}`);
  }
  drawCursor();

}

function resize() {
  drawCanvas.width = window.innerWidth;
  drawCanvas.height = window.innerHeight;
  previewCanvas.width = window.innerWidth;
  previewCanvas.height = window.innerHeight;
  cursorCanvas.width = window.innerWidth;
  cursorCanvas.height = window.innerHeight;
  cursorCanvas.style.cursor = "none"; // Hide the default cursor
}


resize();
window.addEventListener('resize', resize);


let isPreviewingStraightLine = false;
let isPreviewingArrow = false;
let isPreviewingBox = false;
let isPreviewingCircle = false;

drawCanvas.onmousedown = (e) => {
  isPreviewingArrow = false;
  isPreviewingBox = false;
  isPreviewingStraightLine = false;
  isPreviewingCircle = false;
  // window.electronAPI.getSettings().then(s => {
  //     penWidth = s.penWidth || 3; // Use settings or default to 3
  //     arrowHeadLength = s.arrowHead || 20; // Use settings or default to 20
  // });
  if (e.shiftKey && e.metaKey) {
    drawingMode = 'arrow';
  }
  else if (e.metaKey) {
    drawingMode = 'box';
  } else if (e.altKey) {
    drawingMode = 'circle';
  }
  else {
    drawingMode = 'freehand';
  }
  if (drawingMode === 'freehand') {
    drawing = true;
    prevX = e.offsetX;
    prevY = e.offsetY;
    lineStartX = e.offsetX;
    lineStartY = e.offsetY;
    isPreviewingStraightLine = e.shiftKey; // Are we drawing a straight line?
  } else if (drawingMode === 'arrow') {
    drawing = true;
    startX = e.offsetX;
    startY = e.offsetY;
    isPreviewingArrow = true;
  } else if (drawingMode === 'box') {
    drawing = true;
    startX = e.offsetX;
    startY = e.offsetY;
    isPreviewingBox = true;
  } else if (drawingMode === 'circle') {
    drawing = true;
    startX = e.offsetX;
    startY = e.offsetY;
    isPreviewingCircle = true;
  }
};

window.addEventListener('focus', () => {
  drawCanvas.style.cursor = 'none';
});
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    drawCanvas.style.cursor = 'none';
  }
});

document.onkeydown = async (e) => {
  if (e.key === 'g') {
    await invoke('change_color', {
      color: "#00ff00"
    });
  }
  if (e.key === 'r') {
    await invoke('change_color', {
      color: "#ff0000"
    });
  }
  if (e.key === 'b') {
    await invoke('change_color', {
      color: "#0000ff"
    });
  }
  if (e.key === 'y') {
    await invoke('change_color', {
      color: "#ffff00"
    });
  }
  if (e.key === 'p') {
    await invoke('change_color', {
      color: "#ff00ff"
    });
  }
  if (e.key === 'o') {
    await invoke('change_color', {
      color: "#ffa500"
    });
  }
  if (e.key === 'e') {
    clearCanvas();
  }
  if (e.key === 'Escape') {
    const currentWindow = Window.getCurrent();
    await currentWindow.hide();
    // invoke('toggle_draw_action', { show: false });
  }
  if (e.key === 'ArrowUp') {
    if (penWidth < 20) {
      penWidth += 1;
      await updateSetting('penWidth', penWidth);
      drawCursor();
    }
  }
  if (e.key === 'ArrowDown') {
    if (penWidth > 1) {
      penWidth -= 1;
      await updateSetting('penWidth', penWidth);
      drawCursor();
    }
  }
  if (e.key === 'z' && (e.metaKey || e.ctrlKey)) {
    e.preventDefault(); // Prevent default undo action
    undo();
  }
};

drawCanvas.onmousemove = (e) => {
  if (ctx && previewCtx) {
    drawCanvas.style.cursor = 'none';
    if (e.shiftKey && e.metaKey) {
      drawingMode = 'arrow';
    }
    else if (e.metaKey) {
      drawingMode = 'box';
    } else if (e.altKey) {
      drawingMode = 'circle';
    } else {
      drawingMode = 'freehand';
    }
    if (drawingMode === 'freehand' && drawing) {

      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = penWidth;
      ctx.lineCap = 'round';
      previewCtx.strokeStyle = strokeColor;
      previewCtx.lineWidth = penWidth;
      previewCtx.lineCap = 'round';
      // If shift is held either since mousedown or now
      if (isPreviewingStraightLine || e.shiftKey) {
        // Optional: live preview by clearing and redrawing background/border
        previewCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
        previewCtx.beginPath();
        previewCtx.moveTo(lineStartX, lineStartY);
        previewCtx.lineTo(e.offsetX, e.offsetY);
        previewCtx.stroke();
      } else {
        // Normal freehand
        ctx.beginPath();
        ctx.moveTo(prevX, prevY);
        ctx.lineTo(e.offsetX, e.offsetY);
        ctx.stroke();
        prevX = e.offsetX;
        prevY = e.offsetY;
        previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);

      }

    } else if (drawingMode === 'arrow' && drawing) {
      previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      if (isPreviewingArrow) {
        // Draw a preview of the arrow
        drawArrow(previewCtx, startX, startY, e.offsetX, e.offsetY);
      }
    } else if (drawingMode === 'box' && drawing) {
      previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      if (isPreviewingBox) {
        previewCtx.strokeStyle = strokeColor; // or any box color you want
        previewCtx.lineWidth = penWidth;
        previewCtx.strokeRect(
          startX,
          startY,
          e.offsetX - startX,
          e.offsetY - startY
        );
      }
    } else if (drawingMode === 'circle' && drawing) {
      previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      if (isPreviewingCircle) {
        const x = Math.min(startX, e.offsetX);
        const y = Math.min(startY, e.offsetY);
        const w = Math.abs(e.offsetX - startX);
        const h = Math.abs(e.offsetY - startY);
        previewCtx.lineWidth = penWidth;
        previewCtx.strokeStyle = strokeColor;
        previewCtx.beginPath();
        previewCtx.ellipse(
          x + w / 2,        // centerX
          y + h / 2,        // centerY
          w / 2,            // radiusX
          h / 2,            // radiusY
          0,                // rotation
          0,
          Math.PI * 2
        );
        previewCtx.stroke();
      }
    } else {

      mousePos.x = e.offsetX;
      mousePos.y = e.offsetY;
      drawCursor();
    }
  }
}


function drawCursor() {
  if (!cursorCtx) return; // Ensure cursorCtx is defined
  // Clear previous preview
  cursorCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
  // Draw the dot at mouse position
  cursorCtx.beginPath();
  cursorCtx.strokeStyle = strokeColor;
  cursorCtx.arc(mousePos.x, mousePos.y, penWidth / 2, 0, 2 * Math.PI);
  cursorCtx.fillStyle = strokeColor;
  // previewCtx.globalAlpha = 1; // full opacity, change if needed
  cursorCtx.shadowColor = 'rgba(0,0,0,0.18)';
  cursorCtx.shadowBlur = 2;
  cursorCtx.fill();
  // Reset shadow so other drawings aren't affected
  cursorCtx.shadowBlur = 0;
}

drawCanvas.oncontextmenu = (e) => {
  e.preventDefault();
};

drawCanvas.onmouseup = async (e) => {
  if (ctx && previewCtx) {
    if (e.button === 2) {
      // Right-click: do nothing
      drawingMode = 'none';
      drawing = false;
      ctx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
      previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      const currentWindow = Window.getCurrent();
      await currentWindow.hide();
      return;
    }
    previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);

    if (drawingMode === 'freehand' && drawing) {
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = penWidth;
      ctx.lineCap = 'round';
      if (isPreviewingStraightLine || e.shiftKey) {
        // Commit the straight line
        ctx.beginPath();
        ctx.moveTo(lineStartX, lineStartY);
        ctx.lineTo(e.offsetX, e.offsetY);
        ctx.stroke();
      }
      drawing = false;
      isPreviewingStraightLine = false;
    } else if (drawingMode === 'arrow' && drawing) {
      drawing = false;
      drawArrow(ctx, startX, startY, e.offsetX, e.offsetY);
    } else if (drawingMode === 'box' && drawing) {
      drawing = false;
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = penWidth;
      ctx.lineCap = 'round';
      ctx.strokeRect(
        startX,
        startY,
        e.offsetX - startX,
        e.offsetY - startY
      );
    } else if (drawingMode === 'circle' && drawing) {
      drawing = false;
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = penWidth;
      const x = Math.min(startX, e.offsetX);
      const y = Math.min(startY, e.offsetY);
      const w = Math.abs(e.offsetX - startX);
      const h = Math.abs(e.offsetY - startY);

      ctx.beginPath();
      ctx.ellipse(
        x + w / 2,        // centerX
        y + h / 2,        // centerY
        w / 2,            // radiusX
        h / 2,            // radiusY
        0,                // rotation
        0,
        Math.PI * 2
      );
      ctx.stroke();

    }
    saveState(); // Save the state after drawing
  }
};

function undo() {
  if (ctx) {
    if (undoStack.length > 1) {
      undoStack.pop(); // Remove current state
      const imgData = undoStack[undoStack.length - 1];
      let img = new window.Image();
      img.onload = function () {
        ctx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
        ctx.drawImage(img, 0, 0, drawCanvas.width, drawCanvas.height);
      };
      img.src = imgData;
    } else if (undoStack.length === 1) {
      // Clear canvas if only the initial state remains
      ctx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
    }
  }
}

drawCanvas.onmouseleave = () => {
  if (cursorCtx) {
    drawing = false;
    cursorCtx.clearRect(0, 0, cursorCanvas.width, cursorCanvas.height);
  }
};

// Prevent right-click context menu
window.addEventListener('contextmenu', e => e.preventDefault());

function drawArrow(ctx: CanvasRenderingContext2D, fromX: number, fromY: number, toX: number, toY: number) {
  const headlen = arrowHeadLength; // Arrowhead length
  const dx = toX - fromX;
  const dy = toY - fromY;
  const angle = Math.atan2(dy, dx);

  // Calculate endpoint of the shaft (before the arrowhead starts)
  const shaftX = toX - (headlen - 2) * Math.cos(angle);
  const shaftY = toY - (headlen - 2) * Math.sin(angle);

  // Draw shaft
  ctx.strokeStyle = strokeColor; // Use the selected stroke color
  ctx.lineWidth = penWidth;
  ctx.lineCap = 'round';
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
  ctx.fillStyle = strokeColor;
  ctx.fill();
}

// function rehideCursor() {
//   document.body.classList.add('hide-cursor');
//   // Or reapply `cursor: none` directly if needed
//   const drawCanvas = document.getElementById('draw-canvas');
//   if (drawCanvas) drawCanvas.style.cursor = 'none';
// }


// window.electronAPI.onWindowFocused(() => {
//     console.log('Window focused');
//     rehideCursor();
// });

// window.electronAPI.onWindowShown(() => {
//     console.log('Window focused');
//     rehideCursor();
// });


document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    const drawCanvas = document.getElementById('draw-canvas');
    if (drawCanvas) drawCanvas.style.cursor = 'none';
  }
});