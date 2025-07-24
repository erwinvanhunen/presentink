//
//  ScreenSelectionWindow.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-10.
//

import Cocoa
import ScreenCaptureKit
import UserNotifications

class ScreenShotWindow: NSWindow {
    var selectionView: SelectionView!
    private let screenRef: NSScreen
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func becomeKey() {
        super.becomeKey()
        self.makeFirstResponder(self.selectionView)
    }

    override func becomeMain() {
        super.becomeMain()
        self.makeFirstResponder(self.selectionView)
    }

    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        if event.type == .leftMouseDown, !self.isKeyWindow {
            self.makeKeyAndOrderFront(nil)
            self.makeFirstResponder(self.selectionView)
            // Forward the event to selectionView
            self.selectionView.mouseDown(with: event)
        }
    }

    init(screen: NSScreen) {
        self.screenRef = screen
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.selectionView = SelectionView(frame: screen.frame, screen: screen)
        self.contentView = selectionView
        self.makeKeyAndOrderFront(nil)
        self.selectionView.needsDisplay = true
        DispatchQueue.main.async {
            self.makeFirstResponder(self.selectionView)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeWindow),
            name: NSNotification.Name("CloseScreenshotWindows"),
            object: nil
        )

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func closeWindow() {
        self.orderOut(nil)
    }

}

class SelectionView: NSView {

    private var showIntroText: Bool = true

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { return true }

    enum SelectionState: Equatable {
        case none
        case selecting
        case selected
        case moving
        case resizing(corner: ResizeCorner)
    }

    enum ResizeCorner: Equatable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    private var state: SelectionState = .none
    private var startPoint: NSPoint?
    private var selectionRect: NSRect = .zero
    private var lastMousePoint: NSPoint = .zero
    private let screen: NSScreen
    private let handleSize: CGFloat = 8

    var onSelectionComplete: ((NSRect) -> Void)?

    override func resetCursorRects() {
        super.resetCursorRects()
        if state == .selecting || state == .selected {
            // Crosshair for the rest of the area
            addCursorRect(bounds, cursor: .crosshair)
            if state == .selected {
                // Arrow cursor for button bar
                addCursorRect(buttonBar.frame, cursor: .arrow)
                // Moving hand cursor inside selection rectangle
                addCursorRect(selectionRect, cursor: .openHand)
                for (corner, rect) in getResizeHandles() {
                    addCursorRect(rect, cursor: cursorForResizeCorner(corner))
                }
            }
        } else {
            addCursorRect(selectionRect, cursor: .arrow)
        }
    }

    private func cursorForResizeCorner(_ corner: ResizeCorner) -> NSCursor {
        switch corner {
        case .topLeft:
            return NSCursor.frameResize(position: .topLeft, directions: .all)
        case .bottomRight:
            return NSCursor.frameResize(
                position: .bottomRight,
                directions: .all
            )
        case .topRight:
            return NSCursor.frameResize(position: .topRight, directions: .all)
        case .bottomLeft:
            return NSCursor.frameResize(position: .bottomLeft, directions: .all)
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .left, .right:
            return NSCursor.resizeLeftRight
        }
    }

    private func makeIconButton(symbolName: String, action: Selector)
        -> NSButton
    {
        let button = NSButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 6
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = action
        let config = NSImage.SymbolConfiguration(
            pointSize: 18,
            weight: .regular
        )
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }

    private lazy var buttonBar: NSView = {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor =
            NSColor(
                calibratedRed: 156 / 255,
                green: 204 / 255,
                blue: 0 / 255,
                alpha: 0.9
            ).cgColor
        bar.layer?.cornerRadius = 18
        bar.translatesAutoresizingMaskIntoConstraints = false
        let copyButton = makeIconButton(
            symbolName: "clipboard",
            action: #selector(copyAction)
        )
        let saveButton = makeIconButton(
            symbolName: "square.and.arrow.down.fill",
            action: #selector(saveScreenshot)
        )
        let cancelButton = makeIconButton(
            symbolName: "xmark.square.fill",
            action: #selector(cancelAction)
        )

        let stack = NSStackView(views: [saveButton, copyButton, cancelButton])
        stack.orientation = .horizontal
        stack.spacing = 24
        stack.edgeInsets = NSEdgeInsets(
            top: 12,
            left: 18,
            bottom: 12,
            right: 18
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
        bar.isHidden = true
        addSubview(bar)
        return bar
    }()

    override func layout() {
        super.layout()
        positionButtonBar()
    }

    private func positionButtonBar() {
        guard state == .selected, !selectionRect.isEmpty else {
            buttonBar.isHidden = true
            return
        }
        buttonBar.isHidden = false

        let barSize = buttonBar.fittingSize
        var barOrigin = NSPoint(
            x: selectionRect.midX - barSize.width / 2,
            y: selectionRect.minY - barSize.height - 12
        )

        if barOrigin.y < 8 {
            barOrigin.y = selectionRect.maxY + 12
        }
        if barOrigin.y + barSize.height > bounds.height - 8 {
            barOrigin.y = bounds.height - barSize.height - 8
        }
        barOrigin.x = max(8, min(barOrigin.x, bounds.width - barSize.width - 8))

        buttonBar.setFrameOrigin(barOrigin)
    }

    init(frame frameRect: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        let point = event.locationInWindow
        lastMousePoint = point

        switch state {
        case .none:
            showIntroText = false
            startPoint = point
            selectionRect = NSRect(origin: point, size: .zero)
            state = .selecting
        case .selected:
            if let corner = resizeCorner(at: point) {
                state = .resizing(corner: corner)
            } else if selectionRect.contains(point) {
                state = .moving
            } else {
                // Start new selection
                startPoint = point
                selectionRect = NSRect(origin: point, size: .zero)
                state = .selecting
            }
        default:
            break
        }
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = event.locationInWindow
        let delta = NSPoint(
            x: point.x - lastMousePoint.x,
            y: point.y - lastMousePoint.y
        )

        switch state {
        case .selecting:
            if let start = startPoint {
                selectionRect = NSRect(
                    x: min(start.x, point.x),
                    y: min(start.y, point.y),
                    width: abs(point.x - start.x),
                    height: abs(point.y - start.y)
                )
            }
        case .moving:
            selectionRect.origin.x += delta.x
            selectionRect.origin.y += delta.y
            // Keep within screen bounds
            selectionRect.origin.x = max(
                0,
                min(selectionRect.origin.x, bounds.width - selectionRect.width)
            )
            selectionRect.origin.y = max(
                0,
                min(
                    selectionRect.origin.y,
                    bounds.height - selectionRect.height
                )
            )
        case .resizing(let corner):
            resizeSelection(with: delta, corner: corner)
        default:
            break
        }

        lastMousePoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch state {
        case .selecting:
            if selectionRect.width > 10 && selectionRect.height > 10 {
                state = .selected
            } else {
                state = .none
                selectionRect = .zero
            }
        case .moving, .resizing:
            state = .selected
        default:
            break
        }
        needsDisplay = true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c":
                    if case .selected = state {
                        captureScreenshot(copyToClipboard: true)
                        return true
                    }
                case "s":
                    if case .selected = state {
                        saveScreenshot()
                        return true
                    }
                default:
                    break
                }
            } else if event.keyCode == 53 {  // Escape key

                NotificationCenter.default.post(
                    name: NSNotification.Name("CloseScreenshotWindows"),
                    object: nil
                )
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:  // Enter
            if case .selected = state {
                captureScreenshot()
            }
        case 53:  // Escape
            NotificationCenter.default.post(
                name: NSNotification.Name("CloseScreenshotWindows"),
                object: nil
            )
        case 8:  // C
            if event.modifierFlags.contains(.command), case .selected = state {
                captureScreenshot(copyToClipboard: true)
            }
        case 1:  // S
            if event.modifierFlags.contains(.command), case .selected = state {
                saveScreenshot()
            }
        default:
            super.keyDown(with: event)
        }
    }

    private func resizeCorner(at point: NSPoint) -> ResizeCorner? {
        guard case .selected = state else { return nil }

        let handles = getResizeHandles()

        for (corner, rect) in handles {
            if rect.contains(point) {
                return corner
            }
        }
        return nil
    }

    private func getResizeHandles() -> [(ResizeCorner, NSRect)] {
        let half = handleSize / 2
        return [
            (
                .topLeft,
                NSRect(
                    x: selectionRect.minX - half,
                    y: selectionRect.maxY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .topRight,
                NSRect(
                    x: selectionRect.maxX - half,
                    y: selectionRect.maxY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .bottomLeft,
                NSRect(
                    x: selectionRect.minX - half,
                    y: selectionRect.minY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .bottomRight,
                NSRect(
                    x: selectionRect.maxX - half,
                    y: selectionRect.minY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .top,
                NSRect(
                    x: selectionRect.midX - half,
                    y: selectionRect.maxY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .bottom,
                NSRect(
                    x: selectionRect.midX - half,
                    y: selectionRect.minY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .left,
                NSRect(
                    x: selectionRect.minX - half,
                    y: selectionRect.midY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
            (
                .right,
                NSRect(
                    x: selectionRect.maxX - half,
                    y: selectionRect.midY - half,
                    width: handleSize,
                    height: handleSize
                )
            ),
        ]
    }

    private func resizeSelection(with delta: NSPoint, corner: ResizeCorner) {
        var newRect = selectionRect

        switch corner {
        case .topLeft:
            newRect.origin.x += delta.x
            newRect.size.width -= delta.x
            newRect.size.height += delta.y
        case .topRight:
            newRect.size.width += delta.x
            newRect.size.height += delta.y

        case .bottomLeft:
            newRect.origin.x += delta.x
            newRect.size.width -= delta.x
            newRect.origin.y += delta.y
            newRect.size.height -= delta.y
        case .bottomRight:
            newRect.size.width += delta.x
            newRect.origin.y += delta.y
            newRect.size.height -= delta.y
        case .top:
            newRect.size.height += delta.y

        case .bottom:
            newRect.origin.y += delta.y
            newRect.size.height -= delta.y
        case .left:
            newRect.origin.x += delta.x
            newRect.size.width -= delta.x
        case .right:
            newRect.size.width += delta.x
        }

        // Ensure minimum size and keep within bounds
        if newRect.width >= 10 && newRect.height >= 10,
            newRect.minX >= 0, newRect.minY >= 0,
            newRect.maxX <= bounds.width, newRect.maxY <= bounds.height
        {
            selectionRect = newRect
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw dark overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        if state != .none && !selectionRect.isEmpty {
            NSColor.clear.set()
            selectionRect.fill(using: .clear)

            // Draw selection border
            NSColor.systemBlue.setStroke()
            let borderPath = NSBezierPath(rect: selectionRect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // Draw resize handles if selected
            if state == .selected {
                NSColor.systemBlue.setFill()
                for (_, handleRect) in getResizeHandles() {
                    NSBezierPath(rect: handleRect).fill()
                }
            }
        }
        positionButtonBar()
        if showIntroText && state == .none {
               drawIntroText()
           }
    }

    @objc private func copyAction() {
        if case .selected = state {
            captureScreenshot(copyToClipboard: true)
        }
    }
    
    private func drawIntroText() {
        let introText = """
            Drag to select an area. Press Esc to cancel.
            Press Cmd+C to copy, Cmd+S to save.
            """
            let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.clear
        ]
        let size = introText.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width + 40,
            height: size.height + 32
        )
        NSColor(
            calibratedRed: 156 / 255,
            green: 204 / 255,
            blue: 0 / 255,
            alpha: 1
        ).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 8, yRadius: 8).fill()
        let textOrigin = NSPoint(
                x: textRect.midX - size.width / 2,
                y: textRect.midY - size.height / 2
            )
            introText.draw(at: textOrigin, withAttributes: attributes)
    }

//    @objc private func saveAction() {
//        saveScreenshot();
////        // Hide the screenshot window so the save panel appears above it
////        window?.orderOut(nil)
////        let savePanel = NSSavePanel()
////        savePanel.allowedContentTypes = [.png]
////        savePanel.nameFieldStringValue =
////            "Screenshot \(DateFormatter.screenshotFormatter.string(from: Date())).png"
////
////        savePanel.begin { response in
////            if response == .OK, let url = savePanel.url {
////                Task {
////                    await self.performScreenCapture(saveToURL: url)
////                }
////            } else {
////                // If cancelled, close the screenshot window
////                self.window?.orderOut(nil)
////                NotificationCenter.default.post(
////                    name: NSNotification.Name("CloseScreenshotWindows"),
////                    object: nil
////                )
////            }
////        }
//    }

    @objc private func cancelAction() {
        window?.orderOut(nil)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1 second pause
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloseScreenshotWindows"),
                    object: nil
                )
            }
        }
    }

    private func captureScreenshot(copyToClipboard: Bool = false) {
        Task {
            await performScreenCapture(copyToClipboard: copyToClipboard)
        }
    }

    @objc private func saveScreenshot() {
        // Hide the screenshot window so the save panel appears above it
        window?.orderOut(nil)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1 second pause
            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.png]
                savePanel.nameFieldStringValue =
                    "Screenshot \(DateFormatter.screenshotFormatter.string(from: Date())).png"

                // Present from main window, not screenshot window
                let parentWindow = NSApp.mainWindow ?? NSApp.keyWindow
                savePanel.beginSheetModal(for: parentWindow ?? savePanel) {
                    response in
                    if response == .OK, let url = savePanel.url {
                        Task {
                            await self.performScreenCapture(saveToURL: url)
                        }
                    } else {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CloseScreenshotWindows"),
                            object: nil
                        )
                    }
                }
            }
        }

    }

    @MainActor
    private func performScreenCapture(
        copyToClipboard: Bool = false,
        saveToURL: URL? = nil
    ) async {
        do {
            window?.orderOut(nil)
            try await Task.sleep(nanoseconds: 100_000_000)

            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            let screenNumber =
                screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber
            guard
                let display = content.displays.first(where: {
                    $0.displayID == screenNumber?.uint32Value
                })
            else {
                print("Could not find matching display")
                return
            }

            let scale = screen.backingScaleFactor
            let screenFrame = screen.frame
            let pixelWidth = Int(screenFrame.width * scale)
            let pixelHeight = Int(screenFrame.height * scale)

            // Capture the full screen
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = pixelWidth
            config.height = pixelHeight
            config.scalesToFit = false

            let fullImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            // Crop the selection area
            let screenRect = convertToScreenCoordinates(selectionRect)
            let cropRect = CGRect(
                x: screenRect.minX * scale,
                y: screenRect.minY * scale,
                width: screenRect.width * scale,
                height: screenRect.height * scale
            )

            guard let croppedCGImage = fullImage.cropping(to: cropRect) else {
                print("Failed to crop image")
                return
            }

            let logicalSize = NSSize(
                width: cropRect.width / scale,
                height: cropRect.height / scale
            )

            let finalImage: NSImage
            if scale > 1 {
                // Downscale to logical size with high quality
                finalImage = NSImage(size: logicalSize)
                finalImage.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                NSImage(cgImage: croppedCGImage, size: logicalSize)
                    .draw(
                        in: NSRect(origin: .zero, size: logicalSize),
                        from: NSRect(origin: .zero, size: logicalSize),
                        operation: .copy,
                        fraction: 1.0
                    )
                finalImage.unlockFocus()
            } else {
                finalImage = NSImage(cgImage: croppedCGImage, size: logicalSize)
            }

            //            let finalImage = NSImage(
            //                cgImage: croppedCGImage,
            //                size: NSSize(
            //                    width: cropRect.width / scale,
            //                    height: cropRect.height / scale
            //                )
            //            )

            if copyToClipboard {
                copyImageToClipboard(finalImage)
            } else if let url = saveToURL {
                saveImageToDisk(finalImage, url: url)
            } else {
                copyImageToClipboard(finalImage)
            }

            window?.orderOut(nil)
        } catch {
            print("Screenshot capture failed: \(error)")
            window?.makeKeyAndOrderFront(nil)
        }
    }

    private func convertToScreenCoordinates(_ rect: NSRect) -> CGRect {
        // Convert from window coordinates to screen coordinates
        let screenFrame = screen.frame
        let flippedY = screenFrame.height - rect.maxY

        return CGRect(
            x: rect.minX,
            y: flippedY,
            width: rect.width,
            height: rect.height
        )
    }

    private func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        let content = UNMutableNotificationContent()
        content.title = "Screenshot copied"
        content.body =
            "Screenshot copied to clipboard"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        NotificationCenter.default.post(
            name: NSNotification.Name("CloseScreenshotWindows"),
            object: nil
        )
    }

    private func saveImageToDisk(_ image: NSImage, url: URL) {

        guard let tiffData = image.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            print("Failed to convert image to PNG")
            return
        }

        do {
            try pngData.write(to: url)
            let content = UNMutableNotificationContent()
            content.title = "Screenshot Saved"
            content.body =
                "Screenshot saved to \(url.lastPathComponent)"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
            print("Screenshot saved to: \(url.path)")
        } catch {
            print("Failed to save screenshot: \(error)")
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("CloseScreenshotWindows"),
            object: nil
        )
    }
}

extension DateFormatter {
    static let screenshotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()
}
