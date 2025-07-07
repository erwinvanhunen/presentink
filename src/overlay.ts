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
const wrapper = document.getElementById('wrapper') as HTMLDivElement;
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
// let lastMouseX = window.innerWidth / 2;
// let lastMouseY = window.innerHeight / 2;
let placingText = false;
let textInput: HTMLInputElement | null = null;
let textSize = 22;
let centeredCircleCenter = { x: 0, y: 0 };
let widthCenterCircleRadius = 0;
let heightCenterCircleRadius = 0;
let isDraggingTextInput = false;
let dragOffset = { x: 0, y: 0 };

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
    changeColor(color); // Change color without updating tray icon
  });
  window.addEventListener('mousemove', async () => {
    // lastMouseX = e.clientX;
    // lastMouseY = e.clientY;
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

  window.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      const currentWindow = Window.getCurrent();
      currentWindow.setFocus();
      currentWindow.setAlwaysOnTop(true);
    }
  });
  window.addEventListener('focus', () => {
    const currentWindow = Window.getCurrent();
    currentWindow.setFocus();
    currentWindow.setAlwaysOnTop(true);
  });

  window.addEventListener('wheel', (e) => {
    if (!placingText) {
      if (e.deltaY < 0) {
        // Scrolling up
        if (penWidth < 20) {
          penWidth += 1;
          updateSetting('penWidth', penWidth);
          drawCursor();
        }
      } else if (e.deltaY > 0) {
        // Scrolling down
        if (penWidth > 1) {
          penWidth -= 1;
          updateSetting('penWidth', penWidth);
          drawCursor();
        }
      }
    } else {
      if (e.deltaY < 0) {
        textSize += 1;
        updateTextInputWidth();

      } else if (e.deltaY > 0) {
        if (textSize > 1) {
          textSize -= 1;
          updateTextInputWidth();
        }
      }
    }
  });
}

function toggleCanvas(show: boolean): void {
  const window = Window.getCurrent();
  if (!show) {
    wrapper.style.background = 'transparent';
    cancelAddingText();
    clearCanvas();
    window.hide();
  } else {
    wrapper.style.background = 'transparent';
    clearCanvas();
    window.show().then(() => {
      drawingMode = 'freehand'; // Reset to freehand mode 
      drawCursor(); // Redraw the cursor in freehand mode
      window.setFocus();
      window.setAlwaysOnTop(true);
    });
  }
}

function clearCanvas(): void {
  if (ctx) {
    ctx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
  }
  if (cursorCtx) {
    cursorCtx.clearRect(0, 0, cursorCanvas.width, cursorCanvas.height);
  }
  if (previewCtx) {
    previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
  }
}


function saveState() {
  if (undoStack.length >= MAX_UNDO) undoStack.shift(); // Limit history
  undoStack.push(drawCanvas.toDataURL());
}

function changeColor(color: string) {
  strokeColor = color;
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
let isPreviewingCenteredCircle = false;

drawCanvas.onmousedown = (e) => {

  isPreviewingArrow = false;
  isPreviewingBox = false;
  isPreviewingStraightLine = false;
  isPreviewingCircle = false;
  isPreviewingCenteredCircle = false;

  if (e.shiftKey && e.metaKey) {
    drawingMode = 'arrow';
  }
  else if (e.shiftKey && e.altKey) {
    drawingMode = 'centered-circle';
  } else if (e.metaKey) {
    drawingMode = 'box';
  } else if (e.altKey) {
    drawingMode = 'circle';
  } else if (e.ctrlKey) {
    drawingMode = 'marker';
  }
  // if (ctx && previewCtx) {
  //   if (drawingMode === 'marker') {
  //     ctx.globalCompositeOperation = "difference";
  //     previewCtx.globalCompositeOperation = "difference"; // Ensure we draw on top of existing content
  //   } else {
  //     ctx.globalCompositeOperation = "source-over"; // Default for freehand
  //     previewCtx.globalCompositeOperation = "source-over"; // Default for preview
  //   }
  // }
  if (drawingMode === 'freehand' || drawingMode === 'marker') {
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
  } else if (drawingMode === 'centered-circle') {
    drawing = true;
    centeredCircleCenter = { x: e.offsetX, y: e.offsetY };
    widthCenterCircleRadius = 0;
    heightCenterCircleRadius = 0;
    isPreviewingCenteredCircle = true;
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

// document.onkeyup = async (e) => {
//   if (e.ctrlKey) {
//     if (ctx && previewCtx) {
//       ctx.globalCompositeOperation = "source-over"; // Reset composite operation on key release
//       previewCtx.globalCompositeOperation = "source-over"; // Reset composite operation on key release
//       drawingMode = 'none'
//       drawing = false;
//       mousePos.x = lastMouseX;
//       mousePos.y = lastMouseY;
//       drawCursor();
//     }
//   } else {
//    // drawingMode = 'freehand'; // Reset to freehand mode
//     mousePos.x = lastMouseX;
//     mousePos.y = lastMouseY;
//     drawCursor();
//   }
// }

document.onkeyup = async (e) => {
  if (!e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey) {
    if (drawing) return;
    if (drawing) return;
    drawingMode = 'freehand'; // Reset to freehand mode
    drawCursor();
  }
}

document.onkeydown = async (e) => {
  if (e.altKey && e.shiftKey) {
    // If both Alt and Shift are pressed, reset to freehand mode
    drawingMode = 'centered-circle';
    drawCursor();
  } else if (e.shiftKey && e.metaKey) {
    drawingMode = 'arrow';
    drawCursor();
  } else if (e.metaKey) {
    drawingMode = 'box';
    drawCursor();
  } else if (e.altKey) {
    drawingMode = 'circle';
    drawCursor();
  } else if (e.ctrlKey) {
    drawingMode = 'marker';
    drawCursor();
  }
  if (e.key === 'g') {
    if (!placingText) {
      await invoke('change_color', {
        color: "#00ff00"
      });
    }
  }
  if (e.key === 'r') {
    if (!placingText) {
      await invoke('change_color', {
        color: "#ff0000"
      });
    }
  }
  if (e.key === 'b') {
    if (!placingText) {
      await invoke('change_color', {
        color: "#0000ff"
      });
    }
  }
  if (e.key === 'y') {
    if (!placingText) {
      await invoke('change_color', {
        color: "#ffff00"
      });
    }
  }
  if (e.key === 'p') {
    if (!placingText) {
      await invoke('change_color', {
        color: "#ff00ff"
      });
    }
  }
  if (e.key === 'o') {
    if (!placingText) {
      await invoke('change_color', {
        color: "#ffa500"
      });
    }
  }
  if (e.key === 'e') {
    if (!placingText) {
      clearCanvas();
    }
  }
  if (e.key === 'w') {
    if (wrapper.style.background === 'none') {
      wrapper.style.background = "white";
    } else {
      wrapper.style.background = 'transparent';
    }
  }
  if (e.key === 'k') {
    invoke("print_output", { text: `Toggling background color ${wrapper.style.background}` });
    if (wrapper.style.background === 'none') {
      wrapper.style.background = "black";
    } else {
      wrapper.style.background = 'transparent';
    }
  }
  if (e.key === 't' || e.key === 'T') {
    if (!placingText) {
      e.preventDefault();
      placingText = true;
      showTextInput(mousePos.x, mousePos.y); // Use the current drawing cursor position
    }
  }
  if (e.key === 'Escape') {
    if (!placingText) {
      // const currentWindow = Window.getCurrent();
      invoke("stop_draw");
      // await currentWindow.hide();
    }
  }
  if (e.key === 'ArrowUp') {
    if (!placingText) {
      e.preventDefault()
      if (penWidth < 20) {
        penWidth += 1;
        await updateSetting('penWidth', penWidth);
        drawCursor();
      }
    }
  }
  if (e.key === 'ArrowDown') {
    if (!placingText) {
      e.preventDefault();
      if (penWidth > 1) {
        penWidth -= 1;
        await updateSetting('penWidth', penWidth);
        drawCursor();
      }
    }
  }
  if (e.key === 'z' && (e.metaKey || e.ctrlKey)) {
    if (!placingText) {
      e.preventDefault(); // Prevent default undo action
      undo();
    }
  }
};

drawCanvas.onmousemove = (e) => {
  if (ctx && previewCtx) {
    ctx.globalAlpha = 1.0; // Full opacity for freehand
    previewCtx.globalAlpha = 1.0; // Full opacity for preview
    drawCanvas.style.cursor = 'none';
    // if (e.shiftKey && e.metaKey) {
    //   drawingMode = 'arrow';
    // } else if (e.altKey && e.shiftKey) {
    //   drawingMode = 'centered-circle';
    // } else if (e.metaKey) {
    //   drawingMode = 'box';
    // } else if (e.altKey) {
    //   drawingMode = 'circle';
    // } else if (e.ctrlKey) {
    //   drawingMode = 'marker';
    // } else {
    //   drawingMode = 'freehand';
    // }
    if ((drawingMode === 'freehand' || drawingMode === 'marker') && drawing) {
      if (drawingMode === 'marker') {
        ctx.globalAlpha = 0.02; // Semi-transparent marker
        previewCtx.globalAlpha = 0.02; // Semi-transparent marker
        // Adjust line width and cap for marker
        ctx.lineWidth = penWidth * 2; // Make marker thicker
        previewCtx.lineWidth = penWidth * 3; // Make marker thicker
        ctx.lineCap = 'square';
        previewCtx.lineCap = 'square';
        mousePos.x = e.offsetX;
        mousePos.y = e.offsetY;
        drawCursor();
      } else {
        ctx.lineWidth = penWidth;
        previewCtx.lineWidth = penWidth;
        ctx.lineCap = 'round';
        previewCtx.lineCap = 'round';
      }
      ctx.strokeStyle = strokeColor;
      previewCtx.strokeStyle = strokeColor;

      // If shift is held either since mousedown or now
      if (isPreviewingStraightLine || e.shiftKey) {
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
        drawArrow(previewCtx, startX, startY, e.offsetX, e.offsetY);
      }
    } else if (drawingMode === 'box' && drawing) {
      previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      if (isPreviewingBox) {
        previewCtx.strokeStyle = strokeColor;
        previewCtx.lineWidth = penWidth;
        previewCtx.strokeRect(
          startX,
          startY,
          e.offsetX - startX,
          e.offsetY - startY
        );
      }
      prevX = e.offsetX;
      prevY = e.offsetY;
      mousePos.x = e.offsetX;
      mousePos.y = e.offsetY;
      drawCursor();
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
        prevX = e.offsetX;
        prevY = e.offsetY;

      }
      mousePos.x = e.offsetX;
      mousePos.y = e.offsetY;
      drawCursor();
    } else if (drawingMode === 'centered-circle' && drawing) {
      previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      if (isPreviewingCenteredCircle) {
        // Calculate the radius based on the mouse position
        const dx = e.offsetX - centeredCircleCenter.x;
        const dy = e.offsetY - centeredCircleCenter.y;
        widthCenterCircleRadius = Math.sqrt(dx * dx);
        heightCenterCircleRadius = Math.sqrt(dy * dy);
        previewCtx.lineWidth = penWidth;
        previewCtx.strokeStyle = strokeColor;
        previewCtx.beginPath();
        previewCtx.ellipse(
          centeredCircleCenter.x,
          centeredCircleCenter.y,
          widthCenterCircleRadius,
          heightCenterCircleRadius,
          0,
          0,
          Math.PI * 2
        );
        previewCtx.stroke();
        prevX = e.offsetX;
        prevY = e.offsetY;
      }
      mousePos.x = e.offsetX;
      mousePos.y = e.offsetY;
      drawCursor();
    } else {
      mousePos.x = e.offsetX;
      mousePos.y = e.offsetY;
      drawCursor();
    }
  }
}

function showTextInput(x: number, y: number) {
  if (textInput) return;
  textInput = document.createElement('input');
  textInput.id = 'text-helper';
  textInput.type = 'text';
  textInput.style.position = 'absolute';
  textInput.style.left = `${x}px`;
  textInput.style.top = `${y}px`;
  // textInput.style.transform = 'translate(-50%, -50%)';
  textInput.style.fontSize = textSize + 'pt';
  textInput.style.zIndex = '9999';
  textInput.style.padding = '6px 12px';
  textInput.style.borderRadius = '8px';
  textInput.style.border = '2px dashed #0a84ff';
  textInput.style.background = 'rgba(255,255,255,0.12)';
  textInput.style.color = strokeColor;
  textInput.style.boxShadow = '0 2px 8px #0003';
  textInput.style.minWidth = '32px';
  textInput.style.width = '32px';
  textInput.autocomplete = 'off';
  textInput.spellcheck = false;
  textInput.style.cursor = 'move';
  document.body.appendChild(textInput);
  textInput.focus();

  // Drag logic
  textInput.addEventListener('mousedown', (ev) => {
    isDraggingTextInput = true;
    dragOffset.x = ev.clientX - textInput!.offsetLeft;
    dragOffset.y = ev.clientY - textInput!.offsetTop;
    textInput!.style.border = '2.5px solid #0a84ff';
    textInput!.style.background = 'rgba(10,132,255,0.08)';
    ev.preventDefault();
  });

  window.addEventListener('mousemove', onTextInputDrag);
  window.addEventListener('mouseup', stopTextInputDrag);


  // Dynamic width as you type
  textInput.addEventListener('input', () => {
    if (!textInput) return;
    const span = document.createElement('span');
    span.style.visibility = 'hidden';
    span.style.position = 'fixed';
    span.style.fontSize = textInput.style.fontSize;
    span.style.fontFamily = 'system-ui, sans-serif';
    span.textContent = textInput.value || textInput.placeholder || '';
    document.body.appendChild(span);
    textInput.style.width = (span.offsetWidth + 24) + 'px';
    document.body.removeChild(span);
  });

  textInput.onkeydown = (ev) => {
    if (ev.key === 'Enter' && textInput!.value.trim() !== '') {
      placingText = false;
      // Use the top-left position of the input box
      addTextAt(textInput!.offsetLeft + 14, textInput!.offsetTop + 8, textInput!.value);
      document.body.removeChild(textInput!);
      textInput = null;
      window.removeEventListener('mousemove', onTextInputDrag);
      window.removeEventListener('mouseup', stopTextInputDrag);
    }
    if (ev.key === 'Escape') {
      ev.stopPropagation();
      cancelAddingText();
    }
    if (ev.key === 'ArrowUp') {
      ev.preventDefault();
      textSize += 1;
      updateTextInputWidth();
    }
    if (ev.key === 'ArrowDown') {
      if (textSize > 1) {
        ev.preventDefault();
        textSize -= 1;
        updateTextInputWidth();
      }
    }
  };
}

function cancelAddingText() {
  placingText = false;
  if (document.body.contains(textInput!)) {
    document.body.removeChild(textInput!);
  }
  textInput = null;
  window.removeEventListener('mousemove', onTextInputDrag);
  window.removeEventListener('mouseup', stopTextInputDrag);
}

function onTextInputDrag(ev: MouseEvent) {
  if (isDraggingTextInput && textInput) {
    textInput.style.left = `${ev.clientX - dragOffset.x}px`;
    textInput.style.top = `${ev.clientY - dragOffset.y}px`;
  }
}
function stopTextInputDrag() {
  if (textInput) {
    textInput.style.border = '2px dashed #0a84ff';
    textInput.style.background = 'rgba(255,255,255,0.12)';
  }
  isDraggingTextInput = false;
}


function updateTextInputWidth() {
  if (!textInput) return;
  textInput.style.fontSize = textSize + 'pt';

  const span = document.createElement('span');
  span.style.visibility = 'hidden';
  span.style.position = 'fixed';
  span.style.fontSize = textInput.style.fontSize;
  span.style.fontFamily = 'system-ui, sans-serif';
  span.textContent = textInput.value || textInput.placeholder || '';
  document.body.appendChild(span);
  textInput.style.width = (span.offsetWidth + 24) + 'px';
  document.body.removeChild(span);
}

function addTextAt(x: number, y: number, text: string) {
  if (ctx) {
    ctx.font = `${textSize}pt system-ui, sans-serif`;
    ctx.strokeStyle = strokeColor;
    ctx.fillStyle = strokeColor; // Fill color for text
    ctx.lineWidth = 2; // Stroke width for text
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillText(text, x, y);
    saveState();
  }
}

function drawCursor() {
  document.body.style.cursor = 'none'; // Hide the default cursor
  if (!cursorCtx) return;
  cursorCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
  cursorCtx.strokeStyle = strokeColor;
  if (drawingMode === 'box') {
    cursorCtx.strokeRect(mousePos.x - penWidth / 2, mousePos.y - penWidth / 2, penWidth, penWidth);
  } else if (drawingMode === 'circle') {
    cursorCtx.beginPath();
    cursorCtx.ellipse(mousePos.x, mousePos.y, penWidth / 2, penWidth / 2, 0, 0, Math.PI * 2);
    cursorCtx.stroke();
  } else if (drawingMode === 'centered-circle') {
    cursorCtx.beginPath();
    cursorCtx.ellipse(mousePos.x, mousePos.y, penWidth / 2, penWidth / 2, 0, 0, Math.PI * 2);
    cursorCtx.stroke();
    cursorCtx.beginPath();
    cursorCtx.arc(mousePos.x, mousePos.y, 2, 0, 2 * Math.PI);
    cursorCtx.fillStyle = strokeColor;
    cursorCtx.fill();
    cursorCtx.stroke();
  } else if (drawingMode === 'arrow') {
    // Draw a dot
    const radius = penWidth / 2;
    cursorCtx.beginPath();
    cursorCtx.arc(mousePos.x, mousePos.y, radius, 0, 2 * Math.PI);
    cursorCtx.fillStyle = strokeColor;
    //cursorCtx.globalAlpha = 0.7;
    cursorCtx.fill();

    // Draw a small arrow inside the dot, fitting exactly
    const arrowLen = radius * 0.8; // Arrow shaft fits inside the circle
    const arrowHead = Math.max(3, radius * 0.4); // Arrowhead size, smaller than radius

    // Arrow shaft
    cursorCtx.beginPath();
    cursorCtx.moveTo(mousePos.x, mousePos.y + radius * 0.5); // Start a bit below center for visual centering
    cursorCtx.lineTo(mousePos.x, mousePos.y - arrowLen + arrowHead);
    cursorCtx.strokeStyle = "#ccc";
    cursorCtx.lineWidth = 2;
    cursorCtx.stroke();

    // Arrowhead
    cursorCtx.beginPath();
    const tipY = mousePos.y - arrowLen;
    cursorCtx.moveTo(mousePos.x, tipY);
    cursorCtx.lineTo(mousePos.x - arrowHead, tipY + arrowHead);
    cursorCtx.lineTo(mousePos.x + arrowHead, tipY + arrowHead);
    cursorCtx.closePath();
    cursorCtx.fillStyle = "#ccc";
    cursorCtx.fill();
  } else if (drawingMode === 'marker') {
    const w = penWidth;
    const h = penWidth * 2.8;
    const bodyHeight = h * 0.7;
    const tipHeight = h - bodyHeight;

    cursorCtx.save();
    cursorCtx.translate(mousePos.x, mousePos.y);
    cursorCtx.rotate(-Math.PI / 8); // Slant the marker

    // Marker body (above the tip)
    cursorCtx.beginPath();
    cursorCtx.rect(-w / 2, -bodyHeight, w, bodyHeight - tipHeight);
    cursorCtx.fillStyle = strokeColor;
    cursorCtx.strokeStyle = strokeColor;
    cursorCtx.lineWidth = 1.2;
    cursorCtx.fill();
    cursorCtx.stroke();

    // Marker tip (chisel, colored) - tip is at (0,0)
    cursorCtx.beginPath();
    cursorCtx.moveTo(-w / 2, 0 - tipHeight);
    cursorCtx.lineTo(w / 2, 0 - tipHeight);
    cursorCtx.lineTo(0, 0);
    cursorCtx.closePath();
    cursorCtx.fillStyle = strokeColor;
    cursorCtx.globalAlpha = 0.85;
    cursorCtx.fill();
    cursorCtx.globalAlpha = 1.0;
    cursorCtx.strokeStyle = "#444";
    cursorCtx.stroke();

    cursorCtx.restore();
  } else {
    cursorCtx.beginPath();
    cursorCtx.strokeStyle = strokeColor;
    cursorCtx.arc(mousePos.x, mousePos.y, penWidth / 2, 0, 2 * Math.PI);
    cursorCtx.fillStyle = strokeColor;
    cursorCtx.fill();
  }
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

    if ((drawingMode === 'freehand' || (drawingMode === 'marker' && drawing))) {
      if (drawingMode === 'marker') {
        ctx.globalAlpha = 0.02; // Semi-transparent marker
        ctx.lineWidth = penWidth * 3; // Make marker thicker
        ctx.lineCap = 'square'
      } else {
        ctx.globalAlpha = 1.0; // Full opacity for freehand
        ctx.lineWidth = penWidth;
        ctx.lineCap = 'round';
      }
      ctx.strokeStyle = strokeColor;
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

    } else if (drawingMode === 'centered-circle' && drawing) {
      drawing = false;
      ctx.lineWidth = penWidth;
      ctx.strokeStyle = strokeColor;
      ctx.beginPath();
      ctx.ellipse(
        centeredCircleCenter.x,
        centeredCircleCenter.y,
        widthCenterCircleRadius,
        heightCenterCircleRadius,
        0,
        0,
        Math.PI * 2
      );
      ctx.stroke();

    }
    previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
  }
  saveState(); // Save the state after drawing
  drawingMode = 'freehand'; // Reset to freehand mode
  drawCursor(); // Redraw the cursor in freehand mode
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

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    const drawCanvas = document.getElementById('draw-canvas');
    if (drawCanvas) drawCanvas.style.cursor = 'none';
  }
});