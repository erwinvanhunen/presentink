const { app, BrowserWindow, globalShortcut, Tray, Menu, screen: electronScreen, dialog, ipcMain } = require('electron');
const { exec } = require('child_process');
const path = require('path');
const { glob } = require('fs');
const { register } = require('module');
const fs = require('fs').promises; // Use Node's fs/promises for async reading

let settingsWindow: Electron.BrowserWindow | null = null;
let helpWindow: Electron.BrowserWindow | null = null;
let aboutWindow: Electron.BrowserWindow | null = null;
let contextMenu: Electron.Menu | null = null;

let tray: Electron.Tray | null = null;
let overlayWindows: Electron.BrowserWindow[] = [];
let breakTimerWindows: Electron.BrowserWindow[] = [];

let originalScript: ScriptAction[] = [];
let currentScript: ScriptAction[] = [];
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

const { loadSettings, saveSettings } = require('./settings');
const { type } = require('os');
const { Console } = require('console');
const { get } = require('http');

// Load settings at startup
let settings : Settings = loadSettings();

function createOverlayWindows() {
    // Remove previous overlays if any
    overlayWindows.forEach(win => win.close());
    overlayWindows = [];
    const displays = electronScreen.getAllDisplays();
    displays.forEach((display: Electron.Display, idx: number) => {
        const win = new BrowserWindow({
            x: display.bounds.x,
            y: display.bounds.y,
            width: display.bounds.width,
            height: display.bounds.height,
            transparent: true,
            frame: false,
            alwaysOnTop: true,
            hasShadow: false,
            focusable: false, // Not focus-stealing
            skipTaskbar: true,
            collectionBehavior: 'all',
            webPreferences: {
                preload: path.join(__dirname, 'preload.js'),
                contextIsolation: true,
                nodeIntegration: false,
            }
        });

        win.setVisibleOnAllWorkspaces(true);

        win.on('focus', () => {
            win.webContents.send('window-focused');
        });
        win.on('show', () => {
            win.webContents.send('window-shown');
        });

        win.setIgnoreMouseEvents(false); // Set to true if you want passthrough
        win.loadFile(`${__dirname}/overlay.html`);

        // Optional: Open devtools for debugging per window
        //win.webContents.openDevTools();

        overlayWindows.push(win);

    });
    overlayWindows.forEach(win => win.webContents.send('set-mode', 'freehand'));
    changeColor(selectedColor); // Set initial color
}


function toggleOverlay() {
    let anyVisible = false;
    if (overlayWindows.length === 0) {
        createOverlayWindows();
    } else {
        anyVisible = overlayWindows.some(win => win.isVisible());
    }
    const drawMenuItem = contextMenu ? contextMenu.getMenuItemById('drawing-toggle') : null;
    overlayWindows.forEach(win => {
        win.webContents.send('clear-undo');
        win.webContents.send('clear-drawing');
    });
    if (anyVisible) {
        unregisterShortcuts();
        if (tray) tray.setImage(trayIconIdle);
        if (drawMenuItem) drawMenuItem.checked = false;
    } else {
        changeColor(selectedColor); // Reset to default color

        registerShortcuts();
        if (drawMenuItem) drawMenuItem.checked = true;
    }
    if (tray) tray.setContextMenu(contextMenu);

    overlayWindows.forEach(win => {
        if (anyVisible) {
            win.hide();
        } else {
            win.showInactive();
            //win.focus();
            win.setVisibleOnAllWorkspaces(true);
            win.webContents.send('set-mode', 'freehand');
        }
    });
    app.dock.hide();

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
    globalShortcut.unregister('Escape');
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
        const s = loadSettings();
        if (s.penWidth < 20) {
            s.penWidth += 1;
            saveSettings(s);
            overlayWindows.forEach(win => {
                win.webContents.send('update-settings', s);
            });
        }
    });
    globalShortcut.register('Down', () => {
        const s = loadSettings();
        if (s.penWidth > 1) {
            s.penWidth -= 1;
            saveSettings(s);
            overlayWindows.forEach(win => {
                win.webContents.send('update-settings', s);
            });
        }
    });

    globalShortcut.register('Escape', () => {
        toggleOverlay();
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

function changeColor(color: string, setTrayIcon = true) {
    selectedColor = color;
    overlayWindows.forEach(win => {
        win.webContents.send('change-color', color);
    });
    //const anyVisible = overlayWindows.some(win => win.isVisible());
    if (tray && setTrayIcon) {
        switch (selectedColor) {
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
}

function createSettingsWindow() {

    const overlayWasVisible = hideOverlayWindows();

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
    if (settingsWindow) {
        settingsWindow.loadFile(`${__dirname}/settings.html`);
        settingsWindow.setMenu(null); // Hide menu bar
        settingsWindow.on('closed', () => {
            settingsWindow = null;
            if (overlayWasVisible) showOverlayWindows();
        });
    }
}

function createHelpWindow() {

    const overlayWasVisible = hideOverlayWindows();

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
    if (helpWindow) {
        helpWindow.loadFile(`${__dirname}/help.html`);
        helpWindow.setMenu(null);
        helpWindow.on('closed', () => {
            helpWindow = null;
            if (overlayWasVisible)
                showOverlayWindows();
        });
    }
}

function showBreakTimerWindow() {

    hideOverlayWindows();

    if (breakTimerWindows.length) {
        breakTimerWindows.forEach(win => { if (!win.isDestroyed()) win.close(); });
        breakTimerWindows = [];
    }
    const displays = electronScreen.getAllDisplays();
    breakTimerWindows = displays.map((display: Electron.Display, idx: number) => {
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
                preload: path.join(__dirname, 'breaktimerpreload.js')
            }
        });
        win.loadFile(`${__dirname}/breaktimer.html`);
        win.on('closed', () => {
            breakTimerWindows = breakTimerWindows.filter(w => w !== win);
        });
        return win;
    });

}

function showAboutWindow() {
    const overlayWasVisible = hideOverlayWindows();

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
            preload: path.join(__dirname, 'aboutpreload.js'),
            contextIsolation: true,
            nodeIntegration: false
        }
    });
    if (aboutWindow) {
        aboutWindow.loadFile(`${__dirname}/about.html`);
        aboutWindow.setMenu(null);

        aboutWindow.webContents.on('did-finish-load', () => {
            aboutWindow?.webContents.send('set-version', app.getVersion());
        });
        //aboutWindow.webContents.openDevTools();
        aboutWindow.on('closed', () => {
            aboutWindow = null;
            if (overlayWasVisible) {
                showOverlayWindows();
            }
        });
    }
}

function showSplashWindow() {
    const displays = electronScreen.getAllDisplays();
    displays.forEach((display: Electron.Display, idx: number) => {
        const win = new BrowserWindow({
            x: display.bounds.x,
            y: display.bounds.y,
            width: display.bounds.width,
            height: display.bounds.height,
            transparent: true,
            frame: false,
            alwaysOnTop: true,
            hasShadow: false,
            focusable: false, // Not focus-stealing
            skipTaskbar: true,
            webPreferences: {
                contextIsolation: true,
                nodeIntegration: false,
            }
        });
        win.setVisibleOnAllWorkspaces(true);
        win.setMenu(null);
        win.loadFile(`${__dirname}/splash.html`);
        win.webContents.on('did-finish-load', () => {
            setTimeout(() => {
                win.hide();
            }, 3000); // 
        });

        win.show();
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
    tray = new Tray(trayIconIdle);

    if (tray) {
        contextMenu = Menu.buildFromTemplate(getMenuTemplate());
        tray.setToolTip('PresentInk');
        tray.setContextMenu(contextMenu);
    }
    //createOverlayWindows();
    //registerShortcuts();
    globalShortcut.register('Option+Shift+D', () => {
        toggleOverlay();
    });
    globalShortcut.register('Option+Shift+T', () => {
        runScript();
    });
    globalShortcut.register('Option+Shift+B', () => {
        showBreakTimerWindow();
    });
    settings
    if(!settings.launchOnStartup) {
        showSplashWindow();
    }   
});

function getMenuTemplate() {
    return [
        { label: 'Draw', id: 'drawing-toggle', click: () => toggleOverlay(), type: 'checkbox', checked: false, accelerator: 'Option+Shift+D' },

        { type: 'separator' },
        {
            label: 'Color', submenu: [
                { label: 'Red', click: () => changeColor('#ff0000',false), type: 'radio', checked: selectedColor === '#ff0000' },
                { label: 'Green', click: () => changeColor('#00ff00',false), type: 'radio', checked: selectedColor === '#00ff00' },
                { label: 'Blue', click: () => changeColor('#0000ff',false), type: 'radio', checked: selectedColor === '#0000ff' },
                { label: 'Yellow', click: () => changeColor('#ffff00',false), type: 'radio', checked: selectedColor === '#ffff00' },
                { label: 'White', click: () => changeColor('#ffffff',false), type: 'radio', checked: selectedColor === '#ffffff' },
                { label: 'Pink', click: () => changeColor('#ff00ff',false), type: 'radio', checked: selectedColor === '#ff00ff' },
                { label: 'Orange', click: () => changeColor('#ffa500',false), type: 'radio', checked: selectedColor === '#ffa500' },
            ]
        },
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
                    click: async (menuItem: any, browserWindow: any) => {
                        pickFile();
                    }
                },
                {
                    label: fileNameLoaded != "" ? fileNameLoaded : "No script loaded",
                    enabled: false // Disable this item, just for display
                },
                {
                    label: 'Type Text',
                    accelerator: 'Option+Shift+T',
                    click: (menuItem: any, browserWindow: any) => {
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

ipcMain.on('exit-drawing', (event: any) => {
    toggleOverlay();
});

ipcMain.on('close-break-timer', () => {
    if (breakTimerWindows.length) {
        breakTimerWindows.forEach(win => { if (!win.isDestroyed()) win.close(); });
        breakTimerWindows = [];
    }
});

ipcMain.handle('get-settings', () => loadSettings());

ipcMain.on('save-settings', (event: any, newSettings: any) => {
    saveSettings(newSettings);
    // Optionally, broadcast to overlay windows
    overlayWindows.forEach(win =>
        win.webContents.send('update-settings', loadSettings())
    );
});

ipcMain.handle('set-launch-at-login', (event: any, enabled: boolean) => {
   // console.log(app.getPath('exe'));
    // const appFolder = path.dirname(process.execPath)
    // const ourExeName = path.basename(process.execPath)
    // const stubLauncher = path.resolve(appFolder, '..', ourExeName)
    // console.log(stubLauncher);
    app.setLoginItemSettings({
        openAtLogin: enabled,
        path: app.getPath('exe')
    });
});

ipcMain.handle('get-version', () => app.getVersion());

ipcMain.handle('open-donate', (event: any, url: any) => {
    const { shell } = require('electron');
    shell.openExternal(url);
});
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

function getVersion(): any {
    return app.getVersion()
}

function pause(ms: number | undefined) {
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
    while (currentScript.length > 0) {
        const action = currentScript.shift();
        if (action != null) {
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
        win.showInactive();
        // win.focus();
    });
}

function typeTextWithSwift(text: any) {
    const child = exec(keyTyper);

    child.stdin.write(text);
    child.stdin.end();

    child.stdout.on('data', (data: any) => {
        console.log(`KeyTyper stdout: ${data}`);
    });

    child.stderr.on('data', (data: any) => {
        console.error(`KeyTyper stderr: ${data}`);
    });

    child.on('close', (code: number) => {
        if (code !== 0) {
            console.error(`KeyTyper process exited with code ${code}`);
        }
    });
}

function getKeyTyperPath() {

    let appPath = app.getAppPath();

    const isAsar = appPath.endsWith('.asar');
    if (isAsar) {
        appPath = path.dirname(appPath); // .../Contents
    } else {
        // In development, point to your build path, or provide a fallback
        return path.resolve(__dirname, './KeyTyper'); // Adjust as needed for dev
    }

    return path.join(appPath, '../KeyTyper');
}

ipcMain.on('import-script-text', (event: any, { text, name }: any) => {
    originalScript = parseZoomItText(text)
    currentScript = [];
});

async function pickFile() {
    const anyVisible = hideOverlayWindows();
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
            if (tray) tray.setContextMenu(contextMenu);

        } catch (err) {
            console.error('Error reading file:', err);
        }
    }
    if (anyVisible) {
        showOverlayWindows();
    }
    if (tray) tray.setContextMenu(contextMenu);
}