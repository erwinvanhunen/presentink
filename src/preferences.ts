import { getSettings, updateSetting, AppSettings } from './settings';
import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from '@tauri-apps/api/window';

let appSettings: AppSettings;
let penWidthInt = 3;
let arrowHeadLengthInt = 20;
let strokeColor = '#ff0000'; // Default stroke color
const drawShortcutInput = document.getElementById('drawingShortcut') as HTMLInputElement;
const changeDrawShortcutBtn = document.getElementById('changeDrawShortcut') as HTMLButtonElement;
const textShortcutInput = document.getElementById('textShortcut') as HTMLInputElement;
const changeTextShortcutBtn = document.getElementById('changeTextShortcut') as HTMLButtonElement;
const breakShortcutInput = document.getElementById('breakShortcut') as HTMLInputElement;
const changeBreakShortcutBtn = document.getElementById('changeBreakShortcut') as HTMLButtonElement;
const screenshotShortcutInput = document.getElementById('screenshotShortcut') as HTMLInputElement;
const changeScreenshotShortcutBtn = document.getElementById('changeScreenshotShortcut') as HTMLButtonElement;
const resetDrawShortcutBtn = document.getElementById('resetDrawShortcut') as HTMLButtonElement;
const resetTextShortcutBtn = document.getElementById('resetTextShortcut') as HTMLButtonElement;
const resetBreakShortcutBtn = document.getElementById('resetBreakShortcut') as HTMLButtonElement;
const resetScreenshotShortcutBtn = document.getElementById('resetScreenshotShortcut') as HTMLButtonElement;
const checkNowBtn = document.getElementById('checkNowBtn') as HTMLButtonElement;
const lastCheckText = document.getElementById('lastCheckText') as HTMLSpanElement;


// Default shortcuts constant
const DEFAULT_SHORTCUTS = {
    drawing: 'Option+Shift+D',
    text: 'Option+Shift+T',
    break_mode: 'Option+Shift+B',
    screenshot: 'Option+Shift+S',
    preferences: 'Option+Shift+P'
};

let recordingShortcut = false;
let currentShortcutType: 'drawing' | 'text' | 'break_mode' | 'screenshot' | null = null;

window.addEventListener('contextmenu', (e) => {
    e.preventDefault();
});

document.querySelectorAll('.prefs-cat-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.prefs-cat-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const cat = btn.getAttribute('data-cat');
        document.querySelectorAll('.prefs-category').forEach(div => {
            (div as HTMLDivElement).style.display = div.id === 'cat-' + cat ? 'block' : 'none';
        });
    });
});

async function checkForUpdates() {
    checkNowBtn.disabled = true;
    checkNowBtn.classList.add('checking');
    checkNowBtn.textContent = 'Checking...';
    let result: any = null;
    try {
        // Call your version check command
        result = await invoke('check_for_updates') as any;

        if (result.hasUpdate) {
            // Show update available
            lastCheckText.textContent = `Update available: ${result.latestVersion}. Click to visit website.`;
            lastCheckText.style.color = '#32d74b'; // Green
            lastCheckText.style.cursor = 'pointer';
            lastCheckText.addEventListener('click', () => {
                invoke('open_url', { url: 'https://presentink.com' });
            });
        } else {
            // No update available
            lastCheckText.textContent = 'You have the latest version';
            lastCheckText.style.color = '#8e8e93'; // Gray
            lastCheckText.style.cursor = 'default';
            lastCheckText.removeEventListener('click', () => {
                invoke('open_url', { url: 'https://presentink.com' });
            });
        }

        // Update last check time in settings
        // const now = new Date().toISOString();
        appSettings.lastVersionCheck = Math.floor(Date.now() / 1000).toString();
        await updateSetting('lastVersionCheck', Math.floor(Date.now() / 1000).toString());

    } catch (error) {
        console.error('Failed to check for updates:', error);
        lastCheckText.textContent = 'Check failed - try again later';
        lastCheckText.style.color = '#ff6b6b'; // Red
    } finally {
        checkNowBtn.disabled = false;
        checkNowBtn.classList.remove('checking');
        checkNowBtn.textContent = 'Check Now';

        if (!result || !result.hasUpdate) {
            // Reset text color after 5 seconds
            setTimeout(() => {
                lastCheckText.style.color = '#8e8e93';
                updateLastCheckDisplay();
            }, 5000);
        }
    }
}

function updateLastCheckDisplay() {
    const lastCheck = appSettings.lastVersionCheck;
    if (lastCheck && lastCheck !== '0') {
        const date = new Date(parseInt(lastCheck) * 1000);
        const now = new Date();
        const diffDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));

        if (diffDays === 0) {
            lastCheckText.textContent = 'Last checked: Today';
        } else if (diffDays === 1) {
            lastCheckText.textContent = 'Last checked: Yesterday';
        } else if (diffDays < 7) {
            lastCheckText.textContent = `Last checked: ${diffDays} days ago`;
        } else {
            lastCheckText.textContent = `Last checked: ${date.toLocaleDateString()}`;
        }
    } else {
        lastCheckText.textContent = 'Last checked: Never';
    }
}

async function resetShortcutToDefault(type: 'drawing' | 'text' | 'break_mode' | 'screenshot') {
    const defaultShortcut = DEFAULT_SHORTCUTS[type];

    // Check if default shortcut conflicts with current shortcuts
    const conflictingAction = isShortcutInUse(defaultShortcut, type);
    if (conflictingAction) {
        showShortcutError(`Cannot reset: default shortcut conflicts with ${conflictingAction}`);
        return;
    }

    // Update local settings
    let shortCutSettings = appSettings.shortcuts || { ...DEFAULT_SHORTCUTS };
    shortCutSettings[type] = defaultShortcut;
    appSettings.shortcuts = shortCutSettings;

    // Update display
    updateShortcutDisplay(type, defaultShortcut);

    // Save to backend
    try {
        await invoke('update_shortcut', { action: type, shortcut: defaultShortcut });
        console.log(`Reset ${type} shortcut to default: ${defaultShortcut}`);
    } catch (error) {
        console.error(`Failed to reset ${type} shortcut:`, error);
        showShortcutError('Failed to reset shortcut');
    }
}

function createKeyDisplay(shortcutStr: string): string {
    const keys = shortcutStr.split('+').map(key => key.trim());
    return keys.map(key => {
        const isModifier = ['Cmd', 'Ctrl', 'Option', 'Alt', 'Shift'].includes(key);
        let symbol = key;

        // Convert to macOS symbols
        switch (key) {
            case 'Cmd': symbol = '⌘'; break;
            case 'Option':
            case 'Alt': symbol = '⌥'; break;
            case 'Shift': symbol = '⇧'; break;
            case 'Ctrl': symbol = '⌃'; break;
        }

        return `<span class="key${isModifier ? ' modifier' : ''}">${symbol}</span>`;
    }).join('');
}

function updateShortcutDisplay(type: 'drawing' | 'text' | 'break_mode' | 'screenshot', shortcutStr: string) {
    let element: HTMLElement;
    switch (type) {
        case 'drawing':
            element = drawShortcutInput;
            break;
        case 'text':
            element = textShortcutInput;
            break;
        case 'break_mode':
            element = breakShortcutInput;
            break;
        case 'screenshot':
            element = screenshotShortcutInput;
            break;
        default:
            return;
    }

    if (shortcutStr === 'Press keys…') {
        element.textContent = shortcutStr;
        element.classList.add('recording');
    } else {
        element.innerHTML = createKeyDisplay(shortcutStr);
        element.classList.remove('recording');
    }
}

// Generic function to start recording a shortcut
async function startRecordingShortcut(type: 'drawing' | 'text' | 'break_mode' | 'screenshot', input: HTMLInputElement) {
    recordingShortcut = true;
    currentShortcutType = type;
    input.value = 'Press keys…';
    input.classList.add('recording');
    input.focus();

    // Disable global shortcuts to prevent them from triggering
    try {
        await invoke('disable_shortcuts');
        console.log('Shortcuts disabled for recording');
    } catch (error) {
        console.error('Failed to disable shortcuts:', error);
    }
}

// Function to stop recording and re-enable shortcuts
async function stopRecordingShortcut() {
    recordingShortcut = false;
    currentShortcutType = null;

    // Re-enable global shortcuts
    try {
        await invoke('enable_shortcuts');
        console.log('Shortcuts re-enabled');
    } catch (error) {
        console.error('Failed to re-enable shortcuts:', error);
    }
}


window.addEventListener('DOMContentLoaded', async () => {
    appSettings = await getSettings();
    setupEventListeners();
    setupShortcutEventListeners();
    updateUI();
    markDefaultColorFromSettings(appSettings.defaultColor);

});

changeDrawShortcutBtn.addEventListener('click', () => {
    recordingShortcut = true;
    drawShortcutInput.value = 'Press keys…';
    drawShortcutInput.classList.add('recording');
    drawShortcutInput.focus();
});

function setupShortcutEventListeners() {
    // Change button listeners
    changeDrawShortcutBtn.addEventListener('click', () => {
        startRecordingShortcut('drawing', drawShortcutInput);
    });

    changeTextShortcutBtn.addEventListener('click', () => {
        startRecordingShortcut('text', textShortcutInput);
    });

    changeBreakShortcutBtn.addEventListener('click', () => {
        startRecordingShortcut('break_mode', breakShortcutInput);
    });

    changeScreenshotShortcutBtn.addEventListener('click', () => {
        startRecordingShortcut('screenshot', screenshotShortcutInput);
    });

    // Reset button listeners
    resetDrawShortcutBtn.addEventListener('click', () => {
        resetShortcutToDefault('drawing');
    });

    resetTextShortcutBtn.addEventListener('click', () => {
        resetShortcutToDefault('text');
    });

    resetBreakShortcutBtn.addEventListener('click', () => {
        resetShortcutToDefault('break_mode');
    });

    resetScreenshotShortcutBtn.addEventListener('click', () => {
        resetShortcutToDefault('screenshot');
    });
}

// Function to check if a shortcut is already in use
function isShortcutInUse(shortcutStr: string, excludeType?: 'drawing' | 'text' | 'break_mode' | 'screenshot'): string | null {
    const shortcuts = appSettings.shortcuts || DEFAULT_SHORTCUTS;

    const shortcutMap = [
        { type: 'drawing', shortcut: shortcuts.drawing },
        { type: 'text', shortcut: shortcuts.text },
        { type: 'break_mode', shortcut: shortcuts.break_mode },
        { type: 'screenshot', shortcut: shortcuts.screenshot }
    ];

    for (const item of shortcutMap) {
        if (item.type !== excludeType && item.shortcut === shortcutStr) {
            // Return a friendly name for the action
            switch (item.type) {
                case 'drawing': return 'Drawing';
                case 'text': return 'Text Typing';
                case 'break_mode': return 'Break';
                case 'screenshot': return 'Screenshot';
                default: return item.type;
            }
        }
    }

    return null; // Not in use
}

// Function to show an error message
function showShortcutError(message: string) {
    // Create a temporary error message
    const errorDiv = document.createElement('div');
    errorDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: linear-gradient(to bottom, #ff6b6b, #ee5555);
        color: white;
        padding: 12px 16px;
        border-radius: 6px;
        font-size: 13px;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        z-index: 10000;
        animation: slideIn 0.3s ease;
    `;

    errorDiv.textContent = message;
    document.body.appendChild(errorDiv);

    // Add slide-in animation
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideIn {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }
    `;
    document.head.appendChild(style);

    // Remove after 3 seconds
    setTimeout(() => {
        errorDiv.style.animation = 'slideIn 0.3s ease reverse';
        setTimeout(() => {
            document.body.removeChild(errorDiv);
            document.head.removeChild(style);
        }, 300);
    }, 3000);
}

// Update your keydown event handler:
window.addEventListener('keydown', async (e) => {
    if (!recordingShortcut || !currentShortcutType) return;

    e.preventDefault();
    e.stopPropagation();

    let keys = [];
    if (e.metaKey) keys.push('Cmd');
    if (e.ctrlKey) keys.push('Ctrl');
    if (e.altKey) keys.push('Option');
    if (e.shiftKey) keys.push('Shift');

    // Check if this is a non-modifier key
    const isModifierKey = ['Meta', 'Control', 'Alt', 'Shift'].includes(e.key);

    if (!isModifierKey) {
        // Handle Escape key to cancel recording
        if (e.code === 'Escape') {

            // Cancel recording - restore original value
            const shortcuts = appSettings.shortcuts || {
                drawing: 'Option+Shift+D',
                text: 'Option+Shift+T',
                break_mode: 'Option+Shift+B',
                screenshot: 'Option+Shift+S',
                preferences: 'Option+Shift+P'
            };

            // Restore the original shortcut display
            switch (currentShortcutType) {
                case 'drawing':
                    updateShortcutDisplay('drawing', shortcuts.drawing);
                    break;
                case 'text':
                    updateShortcutDisplay('text', shortcuts.text);
                    break;
                case 'break_mode':
                    updateShortcutDisplay('break_mode', shortcuts.break_mode);
                    break;
                case 'screenshot':
                    updateShortcutDisplay('screenshot', shortcuts.screenshot);
                    break;
            }

            await stopRecordingShortcut();
            return;
        }

        // Add the main key
        let mainKey = e.key;

        // Handle special cases for better display
        if (e.code.startsWith('Key')) {
            mainKey = e.code.replace(/^Key/, '').toUpperCase();
        } else if (e.code.startsWith('Digit')) {
            mainKey = e.code.replace(/^Digit/, '');
        } else if (e.code === 'Space') {
            mainKey = 'Space';
        } else if (e.code === 'Comma') {
            mainKey = ',';
        } else if (e.code === 'Period') {
            mainKey = '.';
        } else if (e.code.startsWith('Arrow')) {
            mainKey = e.code; // ArrowUp, ArrowDown, etc.
        } else if (e.code === 'Enter') {
            mainKey = 'Enter';
        } else if (e.code === 'Tab') {
            mainKey = 'Tab';
        } else if (e.code === 'Backspace') {
            mainKey = 'Backspace';
        } else {
            mainKey = e.key.toUpperCase();
        }

        keys.push(mainKey);

        // Complete the shortcut recording
        const shortcutStr = keys.join('+');

        // Check if shortcut is already in use
        const conflictingAction = isShortcutInUse(shortcutStr, currentShortcutType);
        if (conflictingAction) {
            showShortcutError(`This shortcut is already used by ${conflictingAction}`);

            // Restore original shortcut and cancel recording
            const shortcuts = appSettings.shortcuts || DEFAULT_SHORTCUTS;
            switch (currentShortcutType) {
                case 'drawing':
                    updateShortcutDisplay('drawing', shortcuts.drawing);
                    break;
                case 'text':
                    updateShortcutDisplay('text', shortcuts.text);
                    break;
                case 'break_mode':
                    updateShortcutDisplay('break_mode', shortcuts.break_mode);
                    break;
                case 'screenshot':
                    updateShortcutDisplay('screenshot', shortcuts.screenshot);
                    break;
            }

            await stopRecordingShortcut();
            return;
        }

        // Validate that shortcut has at least one modifier
        const hasModifier = keys.some(key => ['Cmd', 'Ctrl', 'Option', 'Shift'].includes(key));
        if (!hasModifier) {
            showShortcutError('Shortcut must include at least one modifier key (⌘, ⌃, ⌥, or ⇧)');

            // Keep recording, don't save this shortcut
            const currentElement = getCurrentShortcutElement();
            if (currentElement) {
                currentElement.textContent = 'Press keys…';
            }
            return;
        }

        updateShortcutDisplay(currentShortcutType, shortcutStr);

        // Update local settings
        let shortCutSettings = appSettings.shortcuts || {
            drawing: 'Option+Shift+D',
            text: 'Option+Shift+T',
            break_mode: 'Option+Shift+B',
            screenshot: 'Option+Shift+S',
            preferences: 'Option+Shift+P'
        };

        // Update the specific shortcut
        switch (currentShortcutType) {
            case 'drawing':
                shortCutSettings.drawing = shortcutStr;
                break;
            case 'text':
                shortCutSettings.text = shortcutStr;
                break;
            case 'break_mode':
                shortCutSettings.break_mode = shortcutStr;
                break;
            case 'screenshot':
                shortCutSettings.screenshot = shortcutStr;
                break;
        }

        appSettings.shortcuts = shortCutSettings; // Update local state

        // Call the backend command and re-enable shortcuts
        try {
            await invoke('update_shortcut', { action: currentShortcutType, shortcut: shortcutStr });
            console.log(`Successfully set ${currentShortcutType} shortcut to ${shortcutStr}`);
        } catch (error) {
            console.error('Failed to update shortcut:', error);
            showShortcutError('Failed to save shortcut');
        } finally {
            // Always re-enable shortcuts, even if update failed
            await stopRecordingShortcut();
        }
    } else {
        // Just show the modifiers being pressed so far
        if (keys.length > 0) {
            const currentElement = getCurrentShortcutElement();
            if (currentElement) {
                currentElement.textContent = keys.join('+') + '+...';
            }
        }
    }
});

// Helper function to get the current shortcut element
function getCurrentShortcutElement(): HTMLElement | null {
    switch (currentShortcutType) {
        case 'drawing': return drawShortcutInput;
        case 'text': return textShortcutInput;
        case 'break_mode': return breakShortcutInput;
        case 'screenshot': return screenshotShortcutInput;
        default: return null;
    }
}



window.addEventListener('blur', async () => {
    if (recordingShortcut) {
        await stopRecordingShortcut();
        // Reset any recording states
        drawShortcutInput.classList.remove('recording');
        textShortcutInput.classList.remove('recording');
        breakShortcutInput.classList.remove('recording');
        screenshotShortcutInput.classList.remove('recording');
    }
});
window.addEventListener('keyup', (e) => {
    if (!recordingShortcut || !currentShortcutType) return;

    // If no modifiers are being held and we're still recording, reset
    if (!e.metaKey && !e.ctrlKey && !e.altKey && !e.shiftKey) {
        let currentInput: HTMLInputElement;
        switch (currentShortcutType) {
            case 'drawing':
                currentInput = drawShortcutInput;
                break;
            case 'text':
                currentInput = textShortcutInput;
                break;
            case 'break_mode':
                currentInput = breakShortcutInput;
                break;
            case 'screenshot':
                currentInput = screenshotShortcutInput;
                break;
            default:
                return;
        }
        currentInput.value = 'Press keys…';
    }
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
    const versionCheck = document.getElementById('checkForUpdates') as HTMLInputElement;
    const closeBtn = document.getElementById('closeBtn');
    if (closeBtn) {
        closeBtn.addEventListener('click', async () => {
            await currentWindow.close();
        });
    }



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

    if (versionCheck) {
        versionCheck.onchange = () => {
            updateSetting('versionCheck', versionCheck.checked);
        };
    }

    checkNowBtn.addEventListener('click', checkForUpdates);

    const colorRadios = document.querySelectorAll('input[type="radio"][name="defaultColor"]');
    colorRadios.forEach(radio => {
        radio.addEventListener('change', () => {
            colorRadios.forEach(r => r.nextElementSibling?.classList.remove('selected'));
            if ((radio as HTMLInputElement).checked) {
                radio.nextElementSibling?.classList.add('selected');
                updateSetting('defaultColor', (radio as HTMLInputElement).value);
                strokeColor = (radio as HTMLInputElement).value; // Update stroke color
                updateUI();
            }

        });
        // Set initial state on load
        if ((radio as HTMLInputElement).checked) {
            radio.nextElementSibling?.classList.add('selected');
        }
    });
}

function drawPenWidth(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement, width: number) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = width;
    ctx.strokeStyle = strokeColor; // Example color
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
    ctx.strokeStyle = strokeColor; // Use the selected stroke color
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
    ctx.fillStyle = strokeColor; // Use the selected fill color
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
    const versionCheck = document.getElementById('checkForUpdates') as HTMLInputElement;
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
    if (versionCheck) {
        if (appSettings.versionCheck === undefined) {
            // If versionCheck is undefined, set it to true by default
            appSettings.versionCheck = true;
            updateSetting('versionCheck', true);
        } else {
            versionCheck.checked = appSettings.versionCheck;
        }
    }
    // Update shortcut displays
    const shortcuts = appSettings.shortcuts || {
        drawing: 'Option+Shift+D',
        text: 'Option+Shift+T',
        break_mode: 'Option+Shift+B',
        screenshot: 'Option+Shift+S',
        preferences: 'Option+Shift+P'
    };

    drawShortcutInput.innerHTML = createKeyDisplay(shortcuts.drawing);
    textShortcutInput.innerHTML = createKeyDisplay(shortcuts.text);
    breakShortcutInput.innerHTML = createKeyDisplay(shortcuts.break_mode);
    screenshotShortcutInput.innerHTML = createKeyDisplay(shortcuts.screenshot);

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

    updateLastCheckDisplay();

}

function markDefaultColorFromSettings(defaultColor: string) {
    const colorRadios = document.querySelectorAll<HTMLInputElement>('input[type="radio"][name="defaultColor"]');
    strokeColor = defaultColor; // Set the global stroke color
    colorRadios.forEach(radio => {
        // Set checked property based on settings
        radio.checked = radio.value === defaultColor;
        // Update .selected class for the color dot
        if (radio.nextElementSibling) {
            if (radio.checked) {
                radio.nextElementSibling.classList.add('selected');
            } else {
                radio.nextElementSibling.classList.remove('selected');
            }
        }
    });
    updateUI();
}