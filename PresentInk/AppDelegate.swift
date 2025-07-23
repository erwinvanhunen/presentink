import ApplicationServices
import Cocoa
import HotKey
@preconcurrency import ScreenCaptureKit
import UserNotifications

extension AppDelegate {
    func hasAccessibilityRights() -> Bool {
        return AXIsProcessTrusted()
    }
}

//import HotKey
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var statusMenu: NSMenu!
    var overlayIsActive = false
    var overlayControllers: [OverlayWindowController] = []
    var breakTimerControllers: [BreakTimerWindowController] = []
    var screenshotControllers: [ScreenShotWindowController] = []
    var rectangleSelectionOverlayControllers:
        [ScreenRecordRectangleController] = []
    var splashController: SplashWindowController?
    var breakTimerController: BreakTimerWindowController?
    var settingsWindowController: SettingsWindowController?
    var helpWindowController: HelpWindowController?
    var hotkeyDraw: HotKey?
    var hotkeyScreenshot: HotKey?
    var hotkeyBreak: HotKey?
    var hotkeyTextType: HotKey?
    var textType: TextTyper?
    var hotkeyRecording: HotKey?
    var hotkeyRectangleRecording: HotKey?
    var selectedTextfile: String?
    var selectedText: [String] = []
    var currentTextIndex: Int = 0
    var isRecording: Bool = false
    var screenRecorder: ScreenRecorder?
    var screenRecorderUrl: URL?
    var screenSelectionOverlays: [ScreenSelectionOverlayWindowController] = []
    var countdownOverlay: CountdownOverlayWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !Settings.shared.launchAtLogin {
            splashController = SplashWindowController()
            splashController?.showWindow(nil)
            splashController?.fadeIn(duration: 0.5)
            splashController?.window?.alphaValue = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // slight delay for smoothness
                self.splashController?.fadeOutAndClose(after: 3.0)

                // Check for updates after splash screen closes
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    if Settings.shared.checkForUpdatesOnStartup {
                        self.checkForUpdatesOnStartup()
                    }
                }
            }
        } else {
            if Settings.shared.checkForUpdatesOnStartup {
                self.checkForUpdatesOnStartup()
            }
        }
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        if let button = statusItem.button {
            button.image = NSImage(named: "TrayIconDefault")
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
        }

        setupHotkeys()

        setupStatusMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(exitDrawingMode),
            name: NSNotification.Name("ExitDrawingMode"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(drawingColorChanged(_:)),
            name: NSNotification.Name("DrawingColorChanged"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeAllBreakTimers),
            name: NSNotification.Name("CloseBreakTimers"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeAllScreenshotWindows),
            name: NSNotification.Name("CloseScreenshotWindows"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyRecordingStarted),
            name: NSNotification.Name("HotkeyRecordingStarted"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyRecordingStopped),
            name: NSNotification.Name("HotkeyRecordingStopped"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(experimentalFeaturesToggled),
            name: NSNotification.Name("experimentalFeaturesToggled"),
            object: nil
        )
    }

    private func setupHotkeys() {
        hotkeyDraw = nil
        hotkeyScreenshot = nil
        hotkeyBreak = nil
        hotkeyTextType = nil
        hotkeyRecording = nil
        hotkeyDraw = HotKey(
            key: Settings.shared.drawHotkey.key ?? .d,
            modifiers: Settings.shared.drawHotkey.modifiers
        )
        hotkeyScreenshot = HotKey(
            key: Settings.shared.screenShotHotkey.key ?? .s,
            modifiers: Settings.shared.screenShotHotkey.modifiers
        )
        hotkeyBreak = HotKey(
            key: Settings.shared.breakTimerHotkey.key ?? .b,
            modifiers: Settings.shared.breakTimerHotkey.modifiers
        )

        hotkeyTextType = HotKey(
            key: Settings.shared.textTypeHotkey.key ?? .t,
            modifiers: Settings.shared.textTypeHotkey.modifiers
        )

        hotkeyRecording = HotKey(
            key: Settings.shared.screenRecordingHotkey.key ?? .r,
            modifiers: Settings.shared.screenRecordingHotkey.modifiers
        )

        hotkeyRectangleRecording = HotKey(
            key: Settings.shared.screenRecordingRectangleHotkey.key ?? .r,
            modifiers: Settings.shared.screenRecordingRectangleHotkey.modifiers
        )

        hotkeyDraw?.keyDownHandler = { [weak self] in
            self?.toggleDrawing()
        }
        hotkeyScreenshot?.keyDownHandler = { [weak self] in
            self?.screenshotAction()
        }
        hotkeyBreak?.keyDownHandler = { [weak self] in
            self?.breakTimeAction()
        }
        hotkeyTextType?.keyDownHandler = { [weak self] in
            self?.typeTextAction()
        }
        hotkeyRecording?.keyDownHandler = { [weak self] in
            Task.detached {
                await self?.recordScreenAction()
            }
        }
        hotkeyRectangleRecording?.keyDownHandler = { [weak self] in
            self?.startRectRecordingFlow()
        }
      
    }

    func setRecordingTrayIcon(_ recording: Bool) {
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                if recording {
                    let symbolConfig = NSImage.SymbolConfiguration(
                        paletteColors: [.red])
                    let symbolImage = NSImage(
                        systemSymbolName: "record.circle.fill",
                        accessibilityDescription: nil
                    )!
                    .withSymbolConfiguration(symbolConfig)!
                    button.image = symbolImage
                } else {
                    button.image = NSImage(named: "TrayIconDefault")
                }
            }
        }
    }

    @objc func recordScreenMenuAction() {
        Task.detached {
            await self.recordScreenAction()
        }
    }

    @objc func recordScreenAction() async {
        if isRecording == false {
            await MainActor.run {
                let screens = NSScreen.screens
                ScreenSelectionDialog.present(for: screens) {
                    [weak self] selectedIndex in
                    guard let self = self, let index = selectedIndex else {
                        return
                    }
                    self.startCountdownAndRecord(screenIndex: index)
                }
            }
        } else {
            do {
                try await screenRecorder!.stop()
                isRecording = false
                setRecordingTrayIcon(false)
                await finishRecording()
            } catch {
                print("Error during recording:", error)
            }
        }
    }

    func finishRecording() async {
        guard let tempURL = screenRecorderUrl else { return }
        await MainActor.run {
            self.closeAllRectangleSelectionOverlayWindows()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let dateString = formatter.string(from: Date())
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.movie]
            savePanel.nameFieldStringValue =
                "screen recording \(dateString).mp4"
            savePanel.title = "Save Screen Recording"
            let response = savePanel.runModal()
            if response == .OK, let destURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }

                    //                    screenRecorder!.convertMovToMp4(
                    //                        inputURL: tempURL,
                    //                        outputURL: destURL
                    //                    )

                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    let content = UNMutableNotificationContent()
                    content.title = "Screen Recording Saved"
                    content.body =
                        "Recording saved to \(destURL.lastPathComponent)"
                    content.sound = .default

                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: nil
                    )
                    UNUserNotificationCenter.current().add(request)

                } catch {
                    let content = UNMutableNotificationContent()
                    content.title = "Screen Recording Failed"
                    content.body =
                        "Failed to save recording: \(error.localizedDescription)"
                    content.sound = .default

                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: nil
                    )

                    UNUserNotificationCenter.current().add(request)
                }
            } else {
                print("User cancelled save. Temp file at \(tempURL)")
                // Optionally, delete temp file
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    func startRectRecordingFlow() {
        for screen in NSScreen.screens {
            let controller = ScreenRecordRectangleController(screen: screen)
            controller.onSelection = { [weak self] screen, rect in
                // Enable click-through on all rectangle overlays
                self?.rectangleSelectionOverlayControllers.forEach {
                    controller in
                    controller.enableClickThrough()
                    if let selectionView = controller.window?.contentView
                        as? ScreenRecordRectangleView
                    {
                        selectionView.switchToRecordingMode()
                    }
                }
                self?.startCountdownAndRecord(screen: screen, cropRect: rect)
            }
            controller.onCancel = { [weak self] in
                self?.closeAllRectangleSelectionOverlayWindows()
            }
            controller.showWindow(nil)
            rectangleSelectionOverlayControllers.append(controller)
        }
    }

    private func activateWindow(windowID: CGWindowID) {
        // Get the process ID (PID) for the window
        guard
            let windowList = CGWindowListCopyWindowInfo(
                [.optionIncludingWindow],
                windowID
            ) as? [[String: Any]],
            let windowDict = windowList.first,
            let pid = windowDict[kCGWindowOwnerPID as String] as? Int32
        else {
            return
        }

        // Create NSRunningApplication from PID and activate it
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateAllWindows])
        }
    }

    private func convertWindowBoundsToScreenCoordinates(_ windowBounds: CGRect)
        -> CGRect
    {
        // macOS window coordinates have origin at bottom-left
        // Screen coordinates have origin at top-left
        guard let mainScreen = NSScreen.main else { return windowBounds }

        let screenHeight = mainScreen.frame.height
        return CGRect(
            x: windowBounds.origin.x,
            y: screenHeight - windowBounds.origin.y - windowBounds.height,
            width: windowBounds.width,
            height: windowBounds.height
        )
    }

    @MainActor
    func startRecordingOnScreen(screenIndex: Int, cropRect: CGRect? = nil) async
    {

        let screen = NSScreen.screens[screenIndex]

        await startRecordingOnScreen(
            screen: screen,
            cropRect: cropRect
        )
    }

    @MainActor
    func startRecordingOnScreen(screen: NSScreen, cropRect: CGRect? = nil) async
    {

        print("Crop selection rect:", cropRect ?? "nil")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        screenRecorderUrl = tempURL

        do {
            guard CGPreflightScreenCaptureAccess() else {
                throw RecordingError("No screen capture permission")
            }

            let displayID =
                screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as! CGDirectDisplayID

            screenRecorder = try await ScreenRecorder(
                url: screenRecorderUrl!,
                displayID: displayID,
                cropRect: cropRect,
                mode: .h264_sRGB
            )
            isRecording = true
            setRecordingTrayIcon(true)
            try await screenRecorder!.start()

        } catch {
            print("Error during recording:", error)
        }
    }

    func removeScreenSelectionOverlays() {
        screenSelectionOverlays.forEach { $0.close() }
        screenSelectionOverlays.removeAll()
    }

    func startCountdownAndRecord(screenIndex: Int, cropRect: CGRect? = nil) {
        if screenIndex != -1 {
            let screen = NSScreen.screens[screenIndex]
            startCountdownAndRecord(screen: screen, cropRect: cropRect)
        }
    }

    func startCountdownAndRecord(screen: NSScreen, cropRect: CGRect? = nil) {

        countdownOverlay = CountdownOverlayWindowController(screen: screen)
        if let window = countdownOverlay?.window {
            window.setFrame(screen.frame, display: true)
        }
        countdownOverlay?.showWindow(nil)
        countdownOverlay?.startCountdown { [weak self] in
            self?.countdownOverlay?.close()
            self?.countdownOverlay = nil
            Task { @MainActor in
                await self?.startRecordingOnScreen(
                    screen: screen,
                    cropRect: cropRect
                )
            }
        }

    }

    @objc func hotkeyRecordingStarted() {
        hotkeyDraw?.isPaused = true
        hotkeyScreenshot?.isPaused = true
        hotkeyBreak?.isPaused = true
        hotkeyTextType?.isPaused = true
        hotkeyRecording?.isPaused = true
    }

    @objc func hotkeyRecordingStopped() {
        setupHotkeys()
        setupStatusMenu()
    }

    @objc func experimentalFeaturesToggled() {
        setupStatusMenu()
    }

    func setupStatusMenu() {
        statusMenu = NSMenu()
        
        // Get hotkey settings
        let drawHotkey = Settings.shared.drawHotkey
        let screenshotHotkey = Settings.shared.screenShotHotkey
        let breakTimerHotkey = Settings.shared.breakTimerHotkey
        let typeTextHotkey = Settings.shared.textTypeHotkey
        let screenRecordingHotkey = Settings.shared.screenRecordingHotkey
        let screenRecordingRectangleHotkey =
            Settings.shared.screenRecordingRectangleHotkey
        
        let drawItem = NSMenuItem(
            title: "Draw",
            action: #selector(drawAction),
            keyEquivalent: drawHotkey.key?.description.lowercased() ?? "d"
        )
        drawItem.keyEquivalentModifierMask = drawHotkey.modifiers
        statusMenu.addItem(drawItem)
        
        let breakItem = NSMenuItem(
            title: "Break Time",
            action: #selector(breakTimeAction),
            keyEquivalent: breakTimerHotkey.key?.description.lowercased() ?? "b"
        )
        breakItem.keyEquivalentModifierMask = breakTimerHotkey.modifiers
        statusMenu.addItem(breakItem)
        
        let screenshotItem = NSMenuItem(
            title: "Screenshot",
            action: #selector(screenshotAction),
            keyEquivalent: screenshotHotkey.key?.description.lowercased() ?? "s"
        )
        screenshotItem.keyEquivalentModifierMask = screenshotHotkey.modifiers
        statusMenu.addItem(screenshotItem)
        
        let recordingMenu = NSMenu(title: "Record Screen")
        
        let screenRecordingItem = NSMenuItem(
            title: "Record screen",
            action: #selector(recordScreenMenuAction),
            keyEquivalent: screenRecordingHotkey.key?.description.lowercased()
            ?? "r"
        )
        screenRecordingItem.keyEquivalentModifierMask =
        screenRecordingHotkey.modifiers
        
        recordingMenu.addItem(screenRecordingItem)
        
        let screenRecordingRectangleItem = NSMenuItem(
            title: "Record cropped",
            action: #selector(recordScreenMenuAction),
            keyEquivalent: screenRecordingRectangleHotkey.key?.description.lowercased()
            ?? "r"
        )
        screenRecordingRectangleItem.keyEquivalentModifierMask =
        screenRecordingRectangleHotkey.modifiers
        
        recordingMenu.addItem(screenRecordingRectangleItem)
        
        let recordingMenuItem = NSMenuItem(
            title: "Screen Recording",
            action: nil,
            keyEquivalent: ""
        )
        recordingMenuItem.submenu = recordingMenu
        statusMenu.addItem(recordingMenuItem)

        let typeTextMenu = NSMenu(title: "Type Text")
        typeTextMenu.addItem(
            NSMenuItem(
                title: "Select Text File...",
                action: #selector(selectTextAction),
                keyEquivalent: ""
            )
        )
        let noFileItem = NSMenuItem(
            title: selectedTextfile != nil
                ? "File selected: " + selectedTextfile! : "No file selected",
            action: nil,
            keyEquivalent: ""
        )
        noFileItem.isEnabled = false
        typeTextMenu.addItem(noFileItem)
        typeTextMenu.addItem(NSMenuItem.separator())

        let typeTextMenuItem = NSMenuItem(
            title: "Type Text",
            action: #selector(typeTextAction),
            keyEquivalent: typeTextHotkey.key?.description.lowercased() ?? "t",
        )
        typeTextMenuItem.keyEquivalentModifierMask = typeTextHotkey.modifiers
        typeTextMenuItem.isEnabled = false
        typeTextMenu.addItem(typeTextMenuItem)

        let typeTextItem = NSMenuItem(
            title: "Text Typer",
            action: nil,
            keyEquivalent: ""
        )
        typeTextItem.submenu = typeTextMenu
        if Settings.shared.showExperimentalFeatures {
            statusMenu.addItem(typeTextItem)
        }

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(
            NSMenuItem(
                title: "Settings...",
                action: #selector(settingsAction),
                keyEquivalent: ""
            )
        )

        statusMenu.addItem(
            NSMenuItem(
                title: "Help",
                action: #selector(helpAction),
                keyEquivalent: ""
            )
        )
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
    }

    @objc private func typeTextAction() {
        if Settings.shared.showExperimentalFeatures {
            var delay: useconds_t = 50000

            guard !selectedText.isEmpty else { return }
            switch Settings.shared.typingSpeed {
            case .slow:
                delay = 100000
            case .normal:
                delay = 50000
            case .fast:
                delay = 0
            }
            if textType == nil {
                textType = TextTyper(typeDelay: delay)
            }
            let entry = selectedText[currentTextIndex]
            waitForAllKeysReleased()
            textType?.typeText(textToType: entry, withDelay: delay)
            currentTextIndex += 1
            if currentTextIndex >= selectedText.count {
                currentTextIndex = 0
            }
        }
    }

    func waitForAllKeysReleased() {
        // Check all key codes (0...127)
        while (0...127).contains(where: {
            CGEventSource.keyState(.combinedSessionState, key: CGKeyCode($0))
        }) {
            usleep(10_000)  // 10 ms
        }
    }

    @objc private func selectTextAction() {
        guard hasAccessibilityRights() else {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText =
                "PresentInk needs Accessibility permissions to type text. Please enable it in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open Preferences")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Select a text file"

        if panel.runModal() == .OK, let url = panel.url {
            selectedTextfile = url.lastPathComponent
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let segments = content.components(separatedBy: "[end]").map {
                    $0.replacingOccurrences(of: "\n", with: "[enter]")
                        .replacingOccurrences(of: "\r", with: "[enter]")
                        .replacingOccurrences(of: "\t", with: "[tab]")
                    //                        .trimmingCharacters(in: .whitespaces)
                }.filter { !$0.isEmpty }
                selectedText = segments
                currentTextIndex = 0
            } catch {
                print("Failed to read file: \(error)")
            }
            setupStatusMenu()
        }

    }

    @objc private func closeAllBreakTimers() {
        breakTimerControllers.forEach { $0.close() }
        breakTimerControllers.removeAll()
    }

    @objc private func closeAllScreenshotWindows() {
        screenshotControllers.forEach { $0.close() }
        screenshotControllers.removeAll()
    }

    @objc private func closeAllRectangleSelectionOverlayWindows() {
        rectangleSelectionOverlayControllers.forEach { $0.close() }
        rectangleSelectionOverlayControllers.removeAll()
    }

    @objc func statusBarButtonClicked(_ sender: Any?) {
        if isRecording {
            Task {
                try? await screenRecorder?.stop()
                isRecording = false
                setRecordingTrayIcon(false)
                await finishRecording()
            }
            return
        }

        overlayControllers.forEach {
            $0.window?.ignoresMouseEvents = true
        }

        if let button = statusItem.button {
            statusItem.menu = statusMenu
            button.performClick(nil)
            DispatchQueue.main.async {
                self.statusItem.menu = nil
                if let overlayWindow =
                    (NSApp.windows.first { $0 is OverlayWindow })
                    as? OverlayWindow
                {
                    overlayWindow.ignoresMouseEvents = false
                }
            }
        }
    }

    @objc func drawAction() {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // Show menu
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async {
                self.statusItem.menu = nil  // Remove to restore left-click handling
            }
        } else {
            // Left click toggles overlay
            toggleDrawing()
        }
    }

    @objc func breakTimeAction() {
        // Close any existing break timer windows
        breakTimerControllers.forEach { $0.close() }
        breakTimerControllers.removeAll()

        // Show break timer on all screens
        for screen in NSScreen.screens {
            let controller = BreakTimerWindowController(screen: screen)
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            if let contentView = controller.window?.contentView {
                controller.window?.makeFirstResponder(contentView)
            }
            breakTimerControllers.append(controller)
        }
    }

    @objc func settingsAction() {
        if let existingController = settingsWindowController {
            // Window already exists, just bring it to front
            existingController.window?.makeKeyAndOrderFront(nil)
            existingController.window?.level = .floating
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Create new settings window
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.showWindow(nil)
            settingsWindowController?.window?.makeKeyAndOrderFront(nil)
            settingsWindowController?.window?.level = .floating
            NSApp.activate(ignoringOtherApps: true)

            // Set up notification to clear reference when window closes
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: settingsWindowController?.window,
                queue: .main
            ) { [weak self] _ in
                self?.settingsWindowController = nil
            }
        }

    }

    @objc func screenshotAction() {
        #if !DEBUG
            if !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
            } else {
                if !screenshotControllers.isEmpty {
                    // Close all screenshot windows
                    screenshotControllers.forEach { $0.close() }
                    screenshotControllers.removeAll()
                } else {
                    // Show screenshot windows
                    for screen in NSScreen.screens {
                        let controller = ScreenShotWindowController(
                            screen: screen
                        )
                        controller.showWindow(nil)
                        controller.window?.makeFirstResponder(nil)
                        if let contentView = controller.window?.contentView {
                            controller.window?.makeFirstResponder(contentView)
                        }
                        screenshotControllers.append(controller)
                    }
                }

            }
        #else

            if !screenshotControllers.isEmpty {
                // Close all screenshot windows
                screenshotControllers.forEach { $0.close() }
                screenshotControllers.removeAll()
            } else {
                // Show screenshot windows
                for screen in NSScreen.screens {
                    let controller = ScreenShotWindowController(screen: screen)
                    controller.showWindow(nil)
                    controller.window?.makeFirstResponder(nil)
                    if let contentView = controller.window?.contentView {
                        controller.window?.makeFirstResponder(contentView)
                    }
                    screenshotControllers.append(controller)
                }
            }
        #endif
    }

    @objc func helpAction() {
        if let existingController = helpWindowController {
            // Window already exists, just bring it to front
            existingController.window?.makeKeyAndOrderFront(nil)
            existingController.window?.level = .floating
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Create new settings window
            helpWindowController = HelpWindowController()
            helpWindowController?.showWindow(nil)
            helpWindowController?.window?.makeKeyAndOrderFront(nil)
            helpWindowController?.window?.level = .floating
            NSApp.activate(ignoringOtherApps: true)

            // Set up notification to clear reference when window closes
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: helpWindowController?.window,
                queue: .main
            ) { [weak self] _ in
                self?.helpWindowController = nil
            }
        }
    }

    func toggleDrawing() {
        if overlayIsActive {
            statusItem.button?.image = NSImage(named: "TrayIconDefault")
            overlayControllers.forEach {
                ($0.window?.contentView as? DrawingView)?.resetToDefaultCursor()
            }

            // Close all overlays
            overlayControllers.forEach { $0.close() }
            overlayControllers.removeAll()
            overlayIsActive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSCursor.setHiddenUntilMouseMoves(false)
                NSCursor.arrow.set()
            }
        } else {
            let color = Settings.shared.defaultColor
            let colorIconMap: [NSColor: String] = [
                .red: "TrayIconRed",
                .green: "TrayIconGreen",
                .blue: "TrayIconBlue",
                .yellow: "TrayIconYellow",
                .orange: "TrayIconOrange",
                .magenta: "TrayIconPink",
            ]
            if let iconName = colorIconMap.first(where: { $0.key == color })?
                .value
            {
                statusItem.button?.image = NSImage(named: iconName)
            } else {
                statusItem.button?.image = NSImage(named: "TrayIconDefault")
            }
            // Create an overlay for each screen
            overlayControllers = NSScreen.screens.map { screen in
                let controller = OverlayWindowController(screen: screen)
                controller.showWindow(nil)
                (controller.window?.contentView as? DrawingView)?
                    .currentLineWidth = CGFloat(Settings.shared.penWidth)
                (controller.window?.contentView as? DrawingView)?.currentColor =
                    Settings.shared.defaultColor
                controller.window?.makeFirstResponder(
                    controller.window?.contentView
                )
                return controller
            }
            overlayIsActive = true
        }
        if let drawItem = statusMenu.item(withTitle: "Draw") {
            drawItem.state = overlayIsActive ? .on : .off
        }
    }
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // Add this method to AppDelegate:
    @objc func exitDrawingMode() {
        toggleDrawing()  // or your method to exit drawing mode
    }

    @objc func drawingColorChanged(_ notification: Notification) {
        guard let color = notification.object as? NSColor else { return }
        let colorIconMap: [NSColor: String] = [
            .red: "TrayIconRed",
            .green: "TrayIconGreen",
            .blue: "TrayIconBlue",
            .yellow: "TrayIconYellow",
            .orange: "TrayIconOrange",
            .magenta: "TrayIconPink",
        ]
        // Find the closest match
        if let iconName = colorIconMap.first(where: { $0.key == color })?.value
        {
            statusItem.button?.image = NSImage(named: iconName)
        }
        overlayControllers.forEach {
            ($0.window?.contentView as? DrawingView)?.currentColor = color
        }
    }

    private func checkForUpdatesOnStartup() {
        if let lastCheck = Settings.shared.lastUpdateCheck {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastCheck) {
                return  // Already checked today
            }
        }
        guard
            let url = URL(
                string:
                    "https://api.github.com/repos/erwinvanhunen/presentink/releases/latest"
            )
        else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue(
            "PresentInker/1.0 (macOS)",
            forHTTPHeaderField: "User-Agent"
        )

        let task = URLSession.shared.dataTask(with: request) {
            data,
            response,
            error in
            guard let data = data,
                let release = try? JSONDecoder().decode(
                    GitHubRelease.self,
                    from: data
                )
            else {
                return
            }

            let currentVersion =
                Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "1.0.0"
            let latestVersion = release.tagName.trimmingCharacters(
                in: CharacterSet(charactersIn: "v")
            )

            if self.isNewerVersion(
                latest: latestVersion,
                current: currentVersion
            ) {
                DispatchQueue.main.async {
                    self.showStartupUpdateAlert(
                        latestVersion: latestVersion,
                        currentVersion: currentVersion,
                        downloadURL: release.htmlUrl
                    )
                }
            }

            // Update last check date
            Settings.shared.lastUpdateCheck = Date()
        }

        task.resume()
    }

    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.components(separatedBy: ".").compactMap {
            Int($0)
        }
        let currentComponents = current.components(separatedBy: ".").compactMap
        { Int($0) }

        let maxCount = max(latestComponents.count, currentComponents.count)

        for i in 0..<maxCount {
            let latestVersion =
                i < latestComponents.count ? latestComponents[i] : 0
            let currentVersion =
                i < currentComponents.count ? currentComponents[i] : 0

            if latestVersion > currentVersion {
                return true
            } else if latestVersion < currentVersion {
                return false
            }
        }

        return false
    }

    private func showStartupUpdateAlert(
        latestVersion: String,
        currentVersion: String,
        downloadURL: URL
    ) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText =
            "PresentInker version \(latestVersion) is available. You are currently using version \(currentVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Remind Me Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(downloadURL)
        }
    }

}
