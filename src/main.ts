import { Window } from '@tauri-apps/api/window';
import { invoke } from "@tauri-apps/api/core";
import { listen } from '@tauri-apps/api/event';
import { open } from '@tauri-apps/plugin-dialog';
import { readTextFile } from '@tauri-apps/plugin-fs';

// let undoStack: any[] = [];
// const MAX_UNDO = 30; // Adjust for memory usage, if you want
// const drawCanvas = document.getElementById('draw-canvas') as HTMLCanvasElement;
// const ctx = drawCanvas.getContext('2d');
// const previewCanvas = document.getElementById('preview-canvas') as HTMLCanvasElement;
// const pr1eviewCtx = previewCanvas.getContext('2d');
// const cursorCanvas = document.getElementById('cursor-canvas') as HTMLCanvasElement;
// const cursorCtx = cursorCanvas.getContext('2d');

// let drawingMode = "freehand"; // Default drawing mode
// let strokeColor = "#ff0000"; // Default stroke color
// let showCanvas = false;
// let drawing = false; // Flag to check if drawing is in progress
// let startX = 0, startY = 0;
// let prevX = 0, prevY = 0;
// let lineStartX = 0, lineStartY = 0;
// let mousePos = { x: 0, y: 0 };

// let windowsVisible = false;
let originalScript: ScriptAction[] = [];
let currentScript: ScriptAction[] = [];
window.addEventListener("DOMContentLoaded", async () => {
  // setTrayIcon()
  // setDockVisibility(false);
  const window = Window.getCurrent();
  window.hide();
  // window.setVisibleOnAllWorkspaces(true);
  
  // register('Alt+Shift+B', (event) => {
  //   if (event.state === "Pressed") {
  //     invoke('show_break_time');
  //   }
  // });
  listen('select-text', () => {
    openFileDialog();
  });
  listen('run-script', (event) => {
    originalScript = parseZoomItText(event.payload as string);
    runScript();
  });
});

async function openFileDialog() {
  const file = await open({
    multiple: false,
    directory: false,
    filters: [
      {
        name: 'Script Files',
        extensions: ['txt'],
      },
    ],
  });

  if (file) {
    const scriptFile = await readTextFile(file);
    invoke("store_script", { script: scriptFile });
  } else {
    invoke("print_output", { text: "no text" });
  }
  let window = Window.getCurrent();
  window.hide();
}

function parseZoomItText(input: string): ScriptAction[] {
    input = input.replace(/\[([^\]\[]+)\]/g, '\n[$1]\n')
        // Remove accidental double newlines if tag is already on a line
        .replace(/\n{2,}/g, '\n')
        .trim(); // Normalize line endings

    const lines = input.split(/\r?\n/);
    const actions: ScriptAction[] = [];
    const pauseRe = /^\s*\[pause\s*:\s*([0-9.]+)\s*\]\s*$/i;
    const endRe = /^\s*\[end\]\s*$/i;

    let buffer: string[] = [];

    function flushBuffer() {
        if (buffer.length > 0) {
            const text = buffer.join('');
            if (text) actions.push({ type: "text", value: text });
            buffer = [];
        }
    }

    for (let line of lines) {
        if (pauseRe.test(line)) {
            flushBuffer();
            const match = line.match(pauseRe);
            if (match) {
                const [, val] = match;
                actions.push({ type: "pause", value: parseFloat(val) });
            }
        } else if (line.trim() === '') {
            // Ignore empty lines
            continue;
        } else if (endRe.test(line)) {
            flushBuffer();
            actions.push({ type: "end", value: null });
            // Do not accumulate buffer after an end tag
        } else {
            buffer.push(line);
        }
    }
    flushBuffer();

    return actions;
}

function pause(ms: number | undefined) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function runScript() {
    // const anyVisible = hideOverlayWindows();
    await pause(100);
    invoke("print_output", { text: "Running script..." });  
    invoke("print_output", { text: `Script ${JSON.stringify(originalScript)}}` });
    if (currentScript.length === 0 && originalScript.length > 0) {
        currentScript = JSON.parse(JSON.stringify(originalScript))
    }

    if (currentScript.length === 0) {
        return;
    }
    while (currentScript.length > 0) {
        const action = currentScript.shift();
        if (action != null) {
            if (action.type === "text") {
                // Split into lines, type one by one
                const lines = action.value.split(/\r?\n/).filter(Boolean);
                for (const line of lines) {
                  invoke("type_text", { text: line.replace(/\\n/g, '') });
                }
            } else if (action.type === "pause") {
                await pause(action.value * 1000); // value is in seconds
            } else if (action.type === "end") {
                break;
            }
        }
    }
    // if (anyVisible) {
    //     {
    //         showOverlayWindows();
    //     }
    // }
}
