const { app, BrowserWindow, globalShortcut, Tray, Menu, screen, ipcMain } = require('electron');

const path = require('path');
const { glob } = require('fs');
const { register } = require('module');
const { electron } = require('process');
let settingsWindow = null;
let helpWindow = null;
let tray = null;
let overlayWindows = [];
const trayIconIdle = path.join(__dirname, 'penimages/pendrawingidle.png');
const trayIconRed = path.join(__dirname, 'penimages/pendrawingred.png');
const trayIconGreen = path.join(__dirname, 'penimages/pendrawinggreen.png');
const trayIconBlue = path.join(__dirname, 'penimages/pendrawingblue.png');
const trayIconYellow = path.join(__dirname, 'penimages/pendrawingyellow.png');
const trayIconWhite = path.join(__dirname, 'penimages/pendrawingwhite.png');
const trayIconPink = path.join(__dirname, 'penimages/pendrawingpink.png');
const trayIconOrange = path.join(__dirname, 'penimages/pendrawingorange.png');
let selectedColor = '#ff0000'; // Default color

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
    if (anyVisible) {
        unregisterShortcuts();
        tray.setImage(trayIconIdle);
    } else {
        changeColor(selectedColor); // Reset to default color
        registerShortcuts();
        win.webContents.send('update-settings', settings); 
    }
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
        changeColor(settings.r);
//        changeColor('#ff0000');
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
        overlayWindows.forEach(win2 => {
            win2.webContents.send('undo');
        });
    });
    globalShortcut.register('e', () => {
        overlayWindows.forEach(win2 => {
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
    if (settingsWindow && !settingsWindow.isDestroyed()) {
        settingsWindow.focus();
        return;
    }
    settingsWindow = new BrowserWindow({
        width: 400,
        height: 350,
        resizable: false,
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
}

function createHelpWindow() {
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
    tray = new Tray(trayIconRed); // Use a "Template Image" for best results on Mac

    const contextMenu = Menu.buildFromTemplate([
        // { label: 'Settings…', click: () => createSettingsWindow() },
        { label: 'Help', click: () => createHelpWindow() },
        { type: 'separator' },
        { label: 'Quit PresentInk', click: () => app.quit() }
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

    // globalShortcut.register('CommandOrControl+1', () => {
    //     overlayWindows.forEach(win => win.webContents.send('set-mode', 'freehand'));
    // });
    // globalShortcut.register('CommandOrControl+2', () => {
    //     overlayWindows.forEach(win => win.webContents.send('set-mode', 'arrow'));
    // });
});



app.on('will-quit', () => {
    globalShortcut.unregisterAll();
});

// ipcMain.on('save-settings', (event, settings) => {
//     // You can store settings in a file, database, or memory
//     // For demo: broadcast to overlay windows
//     store.set('settings', settings);
//     overlayWindows.forEach(win =>
//         win.webContents.send('update-settings', settings)
//     );
//     // Optionally: persist with electron-store or similar
// });

ipcMain.on('exit-drawing', (event) => {
    toggleOverlay();
});


