export { };

declare global {
    interface Window {
        electronAPI: {
            onSetMode: (callback: (event: Electron.IpcRendererEvent, mode: any) => void) => void,
            onClearDrawing: (callback: (event: Electron.IpcRendererEvent) => void) => void,
            onSetColor: (callback: (event: Electron.IpcRendererEvent, color: any) => void) => void,
            onShiftToggle: (callback: (event: Electron.IpcRendererEvent) => void) => void,
            onUndo: (callback: (event: Electron.IpcRendererEvent) => void) => void,
            onClearUndo: (callback: (event: Electron.IpcRendererEvent) => void) => void,
            updateSettings: (callback: (event: Electron.IpcRendererEvent, settings: any) => void) => void,
            exitDrawing: () => void,
            getSettings: () => Promise<any>,
            saveSettings: (settings: any) => void,
            openDonate: (url: string) => Promise<any>,
            writeLog: (message: string) => Promise<void>
            onWindowFocused: (callback: (event: Electron.IpcRendererEvent) => void) => void,
            onWindowShown: (callback: (event: Electron.IpcRendererEvent) => void) => void,
            setLaunchAtLogin: (enabled: boolean) => Promise<void>
        },
        aboutPreload: {
            getVersion: () => Promise<string>,
            openDonate: (url: string) => Promise<void>,
            sendVersion: (version: string) => void
        },
        breakTimerPreload: {
            closeBreakTimer: () => void,
            getSettings: () => Promise<any>
        }
    }

    interface Settings {
        breakTime: number;
        penWidth: number;
        arrowHead: number;
        launchOnStartup: boolean;
    }

    interface ScriptAction {
        type: string,
        value: any
    }
}