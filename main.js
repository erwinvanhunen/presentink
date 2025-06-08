const { app, BrowserWindow, globalShortcut, Tray, Menu, screen, dialog, ipcMain } = require('electron');
const { exec } = require('child_process');
const path = require('path');
const { glob } = require('fs');
const { register } = require('module');
const fs = require('fs').promises; // Use Node's fs/promises for async reading

let settingsWindow = null;
let helpWindow = null;
let aboutWindow = null;
let contextMenu = null;

let tray = null;
let overlayWindows = [];
let breakTimerWindows = [];

let originalScript = [];
let currentScript = [];
let fileNameLoaded = "";

const trayIconIdle = path.join(__dirname, 'penimages/pendrawingidle.png');
const trayIconRed = path.join(__dirname, 'penimages/pendrawingred.png');
const trayIconGreen = path.join(__dirname, 'penimages/pendrawinggreen.png');
const trayIconBlue = path.join(__dirname, 'penimages/pendrawingblue.png');
const trayIconYellow = path.join(__dirname, 'penimages/pendrawingyellow.png');
const trayIconWhite = path.join(__dirname, 'penimages/pendrawingwhite.png');
const trayIconPink = path.join(__dirname, 'penimages/pendrawingpink.png');
const trayIconOrange = path.join(__dirname, 'penimages/pendrawingorange.png');
const keyTyper = getKeyTyperPath(); // Path to the KeyTyper executable
let selectedColor = '#ff0000'; // Default color

console.log(`KeyTyper path: ${keyTyper}`);

const { loadSettings, saveSettings } = require('./settings');
const { type } = require('os');
const { Console } = require('console');
const { get } = require('http');

// Load settings at startup
let settings = loadSettings();

function createOverlayWindows() {
    // Remove previous overlays if any
    overlayWindows.forEach(win => win.close());
    overlayWindows = [];

    const displays = screen.getAllDisplays();
    displays.forEach((display, idx) => {
        const win = new BrowserWindow({
            x: display.bounds.x,
            y: display.bounds.y,
            width: display.bounds.width,
            height: display.bounds.height,
            transparent: true,
            frame: false,
            alwaysOnTop: true,
            hasShadow: false,
            focusable: true, // Not focus-stealing
            skipTaskbar: true,
            collectionBehavior: 'all',
            webPreferences: {
                preload: path.join(__dirname, 'preload.js'),
                contextIsolation: true,
                nodeIntegration: false,
            }
        });

        // if ((process.platform === 'darwin' || process.platform === 'linux')) {
        //     win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
        // }
        win.on('focus', () => {
            win.webContents.send('window-focused');
        });
        win.on('show', () => {
            win.webContents.send('window-shown');
        });

        win.setIgnoreMouseEvents(false); // Set to true if you want passthrough

        win.loadFile('index.html');
        // Optional: Open devtools for debugging per window
        //win.webContents.openDevTools();

        overlayWindows.push(win);
    });
    overlayWindows.forEach(win => win.webContents.send('set-mode', 'freehand'));
}


function toggleOverlay() {
    if (overlayWindows.length === 0) {
        createOverlayWindows();
    }
    const anyVisible = overlayWindows.some(win => win.isVisible());
    const drawMenuItem = contextMenu.getMenuItemById('drawing-toggle');
    overlayWindows.forEach(win => {
        win.webContents.send('clear-undo');
        win.webContents.send('clear-drawing');
    });
    if (anyVisible) {
        unregisterShortcuts();
        tray.setImage(trayIconIdle);
        drawMenuItem.checked = false;
    } else {
        changeColor(selectedColor); // Reset to default color
        registerShortcuts();
        drawMenuItem.checked = true;
    }
    tray.setContextMenu(contextMenu);

    overlayWindows.forEach(win => {
        if (anyVisible) {
            win.hide();
        } else {
            win.show();
            win.focus();
            win.setVisibleOnAllWorkspaces(true);
            win.collectionBehavior = 'all';
            win.webContents.send('set-mode', 'freehand');
        }
    });
}

function unregisterShortcuts() {
    globalShortcut.unregister('g');
    globalShortcut.unregister('r');
    globalShortcut.unregister('b');
    globalShortcut.unregister('e');
    globalShortcut.unregister('y');
    globalShortcut.unregister('w');
    globalShortcut.unregister('p');
    globalShortcut.unregister('o');
    globalShortcut.unregister('Up');
    globalShortcut.unregister('Down');
    globalShortcut.unregister('CommandOrControl+Z');
    globalShortcut.unregister('CommandOrControl+C');
    globalShortcut.unregister('t');
}

function registerShortcuts() {


    globalShortcut.register('g', () => {
        changeColor('#00ff00');
    });
    globalShortcut.register('r', () => {
        changeColor("#ff0000");
    });
    globalShortcut.register('b', () => {
        changeColor('#0000ff');
    });
    globalShortcut.register('y', () => {
        changeColor('#ffff00');
    });
    globalShortcut.register('w', () => {
        changeColor('#ffffff');
    });
    globalShortcut.register('p', () => {
        changeColor('#ff00ff');
    });
    globalShortcut.register('o', () => {
        changeColor('#ffa500');
    });

    globalShortcut.register('Up', () => {
        s = loadSettings();
        if (s.penWidth < 20) {
            s.penWidth += 1;
            saveSettings(s);
            overlayWindows.forEach(win => {
                win.webContents.send('update-settings', s);
            });
        }
    });
    globalShortcut.register('Down', () => {
        s = loadSettings();
        if (s.penWidth > 1) {
            s.penWidth -= 1;
            saveSettings(s);
            overlayWindows.forEach(win => {
                win.webContents.send('update-settings', s);
            });
        }
    });

    globalShortcut.register('CommandOrControl+Z', () => {
        overlayWindows.forEach(win => {
            win.webContents.send('undo');
        });
    });
    globalShortcut.register('e', () => {
        overlayWindows.forEach(win => {
            win.webContents.send('clear-drawing');
        });
    });
}

function changeColor(color) {
    selectedColor = color;
    overlayWindows.forEach(win => {
        win.webContents.send('change-color', color);
    });
    switch (color) {
        case '#00ff00':
            tray.setImage(trayIconGreen);
            break;
        case '#ff0000':
            tray.setImage(trayIconRed);
            break;
        case '#0000ff':
            tray.setImage(trayIconBlue);
            break;
        case '#ffff00':
            tray.setImage(trayIconYellow);
            break;
        case '#ffffff':
            tray.setImage(trayIconWhite);
            break;
        case '#ff00ff':
            tray.setImage(trayIconPink);
            break;
        case '#ffa500':
            tray.setImage(trayIconOrange);
            break;
        default:
            tray.setImage(trayIconIdle);
    }
}

function createSettingsWindow() {

    overlayWasVisible = hideOverlayWindows();

    if (settingsWindow && !settingsWindow.isDestroyed()) {
        settingsWindow.focus();
        return;
    }
    settingsWindow = new BrowserWindow({
        width: 640,
        height: 350,
        resizable: true,
        minimizable: false,
        maximizable: false,
        modal: true,
        title: "PresentInk Settings",
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: true,
            nodeIntegration: false
        }
    });
    settingsWindow.loadFile('settings.html');
    settingsWindow.setMenu(null); // Hide menu bar

    settingsWindow.on('closed', () => {
        settingsWindow = null;
        if (overlayWasVisible) showOverlayWindows();
    });
}

function createHelpWindow() {

    overlayWasVisible = hideOverlayWindows();

    if (helpWindow && !helpWindow.isDestroyed()) {
        helpWindow.focus();
        return;
    }
    helpWindow = new BrowserWindow({
        width: 640,
        height: 670,
        resizable: true,
        minimizable: false,
        maximizable: false,
        title: "PresentInk Help",
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: true,
            nodeIntegration: false
        }
    });
    helpWindow.loadFile('help.html');
    helpWindow.setMenu(null);

    helpWindow.on('closed', () => {
        helpWindow = null;
        showOverlayWindows();
    });
}

function showBreakTimerWindow() {

    hideOverlayWindows();

    if (breakTimerWindows.length) {
        breakTimerWindows.forEach(win => { if (!win.isDestroyed()) win.close(); });
        breakTimerWindows = [];
    }
    const displays = screen.getAllDisplays();
    breakTimerWindows = displays.map((display, idx) => {
        const win = new BrowserWindow({
            x: display.bounds.x,
            y: display.bounds.y,
            width: display.bounds.width,
            height: display.bounds.height,
            fullscreen: true,
            backgroundColor: '#ffffff',
            frame: false,
            alwaysOnTop: true,
            skipTaskbar: true,
            webPreferences: {
                nodeIntegration: false,
                contextIsolation: true,
                preload: path.join(__dirname, 'breaktimer-preload.js')
            }
        });
        win.loadFile('breaktimer.html');
        win.on('closed', () => {
            breakTimerWindows = breakTimerWindows.filter(w => w !== win);
        });
        return win;
    });

}

function showAboutWindow() {
    overlayWasVisible = hideOverlayWindows();

    if (aboutWindow && !aboutWindow.isDestroyed()) {
        aboutWindow.focus();
        return;
    }
    aboutWindow = new BrowserWindow({
        width: 340,
        height: 410,
        resizable: false,
        minimizable: false,
        maximizable: false,
        title: "About PresentInk",
        alwaysOnTop: true,
        webPreferences: {
            preload: path.join(__dirname, 'about-preload.js'),
            contextIsolation: true,
            nodeIntegration: false
        }
    });
    aboutWindow.loadFile('about.html');
    aboutWindow.setMenu(null);
    aboutWindow.on('closed', () => {
        aboutWindow = null;
        showOverlayWindows();
    });
}

app.whenReady().then(() => {

    app.dock.hide();

    const template = [
        {
            label: app.name,
            submenu: [
                { role: 'quit' }
            ]
        }
    ];

    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);

    // Setup tray/menu bar icon
    tray = new Tray(trayIconRed);

    contextMenu = Menu.buildFromTemplate(getMenuTemplate());
    tray.setToolTip('PresentInk');
    tray.setContextMenu(contextMenu);

    createOverlayWindows();
    registerShortcuts();
    globalShortcut.register('CommandOrControl+Shift+D', () => {
        toggleOverlay();
    });
    globalShortcut.register('CommandOrControl+Shift+T', () => {
        runScript();
    });
    globalShortcut.register('CommandOrControl+Shift+B', () => {
        showBreakTimerWindow();
    });

});

function getMenuTemplate() {
    return [
        { label: 'Draw', id: 'drawing-toggle', click: () => toggleOverlay(), type: 'checkbox', checked: true, accelerator: 'CommandOrControl+Shift+D' },
        { type: 'separator' },
        { label: 'Settings…', click: () => createSettingsWindow() },
        { label: 'Help', click: () => createHelpWindow() },
        { type: 'separator' },
        { label: 'About PresentInk', click: () => showAboutWindow() },
        { type: 'separator' },
        {
            label: 'Text Typer',
            submenu: [
                {
                    id: 'select-script-file',
                    label: 'Select Script file',
                    click: async (menuItem, browserWindow) => {
                        pickFile();
                    }
                },
                {
                    label: fileNameLoaded != "" ? fileNameLoaded : "No script loaded",
                    enabled: false // Disable this item, just for display
                },
                {
                    label: 'Type Text',
                    accelerator: 'CmdOrCtrl+Shift+T',
                    click: (menuItem, browserWindow) => {
                        runScript();
                    }
                },

            ]
        },
        { type: 'separator' },
        { label: 'Quit PresentInk', click: () => app.quit(), accelerator: 'CommandOrControl+Q' },
    ];
}

app.on('will-quit', () => {
    globalShortcut.unregisterAll();
});

ipcMain.on('exit-drawing', (event) => {
    toggleOverlay();
});

ipcMain.on('close-break-timer', () => {
    if (breakTimerWindows.length) {
        breakTimerWindows.forEach(win => { if (!win.isDestroyed()) win.close(); });
        breakTimerWindows = [];
    }
});

ipcMain.handle('get-settings', () => loadSettings());

ipcMain.on('save-settings', (event, newSettings) => {
    saveSettings(newSettings);
    // Optionally, broadcast to overlay windows
    overlayWindows.forEach(win =>
        win.webContents.send('update-settings', loadSettings())
    );
});

ipcMain.handle('get-version', () => app.getVersion());

ipcMain.handle('open-donate', (event, url) => {
    const { shell } = require('electron');
    shell.openExternal(url);
});

ipcMain.handle('write-log', (event, message) => {
    console.log(message);
});

function parseZoomItText(input) {
    input = input.replace(/\[([^\]\[]+)\]/g, '\n[$1]\n')
        // Remove accidental double newlines if tag is already on a line
        .replace(/\n{2,}/g, '\n')
        .trim(); // Normalize line endings

    const lines = input.split(/\r?\n/);
    const actions = [];
    const pauseRe = /^\s*\[pause\s*:\s*([0-9.]+)\s*\]\s*$/i;
    const endRe = /^\s*\[end\]\s*$/i;

    let buffer = [];

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
            const [, val] = line.match(pauseRe);
            actions.push({ type: "pause", value: parseFloat(val) });
        } else if (line.trim() === '') {
            // Ignore empty lines
            continue;
        } else if (endRe.test(line)) {
            flushBuffer();
            actions.push({ type: "end" });
            // Do not accumulate buffer after an end tag
        } else {
            buffer.push(line);
        }
    }
    flushBuffer();

    return actions;
}

function pause(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function runScript() {
    const anyVisible = hideOverlayWindows();
    pause(100);
    if (currentScript.length === 0 && originalScript.length > 0) {
        currentScript = JSON.parse(JSON.stringify(originalScript))
    }

    if (currentScript.length === 0) {
        return;
    }
    console.log("Running script with actions:", currentScript);
    while (currentScript.length > 0) {
        const action = currentScript.shift();

        if (action.type === "text") {
            // Split into lines, type one by one
            const lines = action.value.split(/\r?\n/).filter(Boolean);
            for (const line of lines) {
                typeTextWithSwift(line.replace(/\\n/g, ''));
            }
        } else if (action.type === "pause") {
            await pause(action.value * 1000); // value is in seconds
        } else if (action.type === "end") {
            break;
        }

    }
    if (anyVisible) {
        {
            showOverlayWindows();
        }
    }
}

function hideOverlayWindows() {
    const anyVisible = overlayWindows.some(win => win && !win.isDestroyed() && win.isVisible());

    if (anyVisible) {

        overlayWindows.forEach(win => { if (win && !win.isDestroyed()) win.hide(); });
        unregisterShortcuts();
    }
    return anyVisible;
}

function showOverlayWindows() {
    registerShortcuts();

    overlayWindows.forEach(win => {
        win.show();
        win.focus();
    });
}

function typeTextWithSwift(text) {
    console.warn(`Typing text: ${text}`);
    const child = exec(keyTyper);

    child.stdin.write(text);
    child.stdin.end();

    child.stdout.on('data', (data) => {
        console.log(`KeyTyper stdout: ${data}`);
    });

    child.stderr.on('data', (data) => {
        console.error(`KeyTyper stderr: ${data}`);
    });

    child.on('close', (code) => {
        if (code !== 0) {
            console.error(`KeyTyper process exited with code ${code}`);
        }
    });
}

function getKeyTyperPath() {

    let appPath = app.getAppPath();

    console.log(`App path: ${appPath}`);

    const isAsar = appPath.endsWith('.asar');
    if (isAsar) {
        appPath = path.dirname(appPath); // .../Contents
    } else {
        // In development, point to your build path, or provide a fallback
        return path.resolve(__dirname, './KeyTyper'); // Adjust as needed for dev
    }

    return path.join(appPath, '../KeyTyper');
}

ipcMain.on('import-script-text', (event, { text, name }) => {
    originalScript = parseZoomItText(text)
    currentScript = [];
});

async function pickFile() {
    anyVisible = hideOverlayWindows();
    const { canceled, filePaths } = await dialog.showOpenDialog({
        title: "Select a script file",
        filters: [{ name: "Text Files", extensions: ["txt"] }],
        properties: ["openFile"]
    });
    if (!canceled && filePaths.length > 0) {

        try {
            const path = require('path');
            const fileName = path.basename(filePaths[0]);
            const content = await fs.readFile(filePaths[0], 'utf-8');

            originalScript = parseZoomItText(content);
            currentScript = [];

            fileNameLoaded = fileName;
            contextMenu = Menu.buildFromTemplate(getMenuTemplate());
            tray.setContextMenu(contextMenu);
        } catch (err) {
            console.error('Error reading file:', err);
        }
    }
    if (anyVisible) {
        showOverlayWindows();
    }
    tray.setContextMenu(contextMenu);
}