const { app, BrowserWindow, globalShortcut, screen } = require('electron');
const path = require('path');
const { Menu } = require('electron');
const { glob } = require('fs');

let overlayWindows = [];


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
    } else {
        globalShortcut.register('g', () => {
            changeColor('#00ff00');
        });
        globalShortcut.register('r', () => {
            changeColor('#ff0000');
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
                win2.webContents.send('clear-drawing');
            });
        });


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

function changeColor(color) {
    overlayWindows.forEach(win => {
        win.webContents.send('change-color', color);
    });
}



app.whenReady().then(() => {

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
    createOverlayWindows();
  
    globalShortcut.register('CommandOrControl+Shift+D', () => {
        toggleOverlay();
    });

    globalShortcut.register('CommandOrControl+1', () => {
        overlayWindows.forEach(win => win.webContents.send('set-mode', 'freehand'));
    });
    globalShortcut.register('CommandOrControl+2', () => {
        overlayWindows.forEach(win => win.webContents.send('set-mode', 'arrow'));
    });
});



app.on('will-quit', () => {
    globalShortcut.unregisterAll();
});



