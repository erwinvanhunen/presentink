const { app, BrowserWindow, globalShortcut, Tray, Menu, screen, ipcMain } = require('electron');

const path = require('path');
const { glob } = require('fs');
const { register } = require('module');
const { electron } = require('process');
let settingsWindow = null;
let helpWindow = null;
let breakTimerWindow = null;
let aboutWindow = null;
let contextMenu = null;

let tray = null;
let overlayWindows = [];
let breakTimerWindows = [];

const trayIconIdle = path.join(__dirname, 'penimages/pendrawingidle.png');
const trayIconRed = path.join(__dirname, 'penimages/pendrawingred.png');
const trayIconGreen = path.join(__dirname, 'penimages/pendrawinggreen.png');
const trayIconBlue = path.join(__dirname, 'penimages/pendrawingblue.png');
const trayIconYellow = path.join(__dirname, 'penimages/pendrawingyellow.png');
const trayIconWhite = path.join(__dirname, 'penimages/pendrawingwhite.png');
const trayIconPink = path.join(__dirname, 'penimages/pendrawingpink.png');
const trayIconOrange = path.join(__dirname, 'penimages/pendrawingorange.png');
let selectedColor = '#ff0000'; // Default color


const { loadSettings, saveSettings } = require('./settings');

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
            focusable: false, // Not focus-stealing
            skipTaskbar: true,
            webPreferences: {
                preload: path.join(__dirname, 'preload.js'),
                contextIsolation: true,
                nodeIntegration: false,
            }
        });

        win.setIgnoreMouseEvents(false); // Set to true if you want passthrough

        win.loadFile('index.html');
        // Optional: Open devtools for debugging per window
        // win.webContents.openDevTools();

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
    globalShortcut.unregister('CommandOrControl+Z');
    globalShortcut.unregister('CommandOrControl+C');
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

    overlayWasVisible = overlayWindows.some(win => win.isVisible());
    overlayWindows.forEach(win => win.hide());

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
        if (overlayWasVisible) overlayWindows.forEach(win => win.show());
    });
}

function createHelpWindow() {

    overlayWasVisible = overlayWindows.some(win => win.isVisible());
    overlayWindows.forEach(win => win.hide());

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
        if (overlayWasVisible) overlayWindows.forEach(win => win.show());
    });
}

function showBreakTimerWindow() {

    overlayWasVisible = overlayWindows.some(win => win.isVisible());
    overlayWindows.forEach(win => win.hide());

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
    overlayWasVisible = overlayWindows.some(win => win.isVisible());
    overlayWindows.forEach(win => win.hide());
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

    contextMenu = Menu.buildFromTemplate([
        { label: 'Draw', id: 'drawing-toggle', click: () => toggleOverlay(), type: 'checkbox', checked: true, accelerator: 'CommandOrControl+Shift+D' },
        { type: 'separator' },
        { label: 'Settings…', click: () => createSettingsWindow() },
        { label: 'Help', click: () => createHelpWindow() },
        { type: 'separator' },
        { label: 'About PresentInk', click: () => showAboutWindow() },
        { type: 'separator' },
        { label: 'Quit PresentInk', click: () => app.quit(), accelerator: 'CommandOrControl+Q' },
    ]);
    tray.setToolTip('PresentInk');
    tray.setContextMenu(contextMenu);

    createOverlayWindows();
    registerShortcuts();
    globalShortcut.register('CommandOrControl+Shift+D', () => {
        overlayWindows.forEach(win => {
            win.webContents.send('clear-undo');
            win.webContents.send('clear-drawing');
        });
        toggleOverlay();

    });

    globalShortcut.register('CommandOrControl+Shift+B', () => {
        showBreakTimerWindow();
    });

});



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