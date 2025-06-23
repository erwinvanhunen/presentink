import { Window } from '@tauri-apps/api/window';
import { invoke } from "@tauri-apps/api/core";
import { listen } from '@tauri-apps/api/event';
import { open } from '@tauri-apps/plugin-dialog';
import { readTextFile } from '@tauri-apps/plugin-fs';
import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from '@tauri-apps/plugin-notification';

let originalScript: ScriptAction[] = [];
let currentScript: ScriptAction[] = [];
let permissionGranted: boolean = false;

window.addEventListener("DOMContentLoaded", async () => {
  const window = Window.getCurrent();
  window.hide();

  permissionGranted = await isPermissionGranted();

  // If not we need to request it
  if (!permissionGranted) {
    const permission = await requestPermission();
    permissionGranted = permission === 'granted';
  }

  listen('select-text', () => {
    openFileDialog();
  });

  listen('run-script', () => {
    // originalScript = parseZoomItText(event.payload as string);
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
    originalScript = parseZoomItText(scriptFile);
    if (permissionGranted) {
      sendNotification({ title: 'PresentInk', body: `Script loaded: ${getFilename(file)}` });
      invoke('set_file_name', { name: `File: ${getFilename(file)}` });
    }
  } else {
    invoke("print_output", { text: "no text" });
  }

  let window = Window.getCurrent();
  window.hide();
}

function getFilename(path: string): string {
  return path.split(/[\\/]/).pop() || path;
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
}
