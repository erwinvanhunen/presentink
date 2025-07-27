import AVFoundation
import Cocoa
import ScreenCaptureKit

class MagnifierOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.setFrame(screen.frame, display: true)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .mainMenu
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func close() {
        if let contentView = contentView as? MagnifierOverlayView {
            contentView.cleanup()
        }
        super.close()
    }
}

class MagnifierOverlayView: NSView {
    private var mouseLocation: NSPoint = NSEvent.mouseLocation
    private var magnifierRadius: CGFloat {
        get {
            return Settings.shared.magnifierRadius
        }
        set {
            Settings.shared.magnifierRadius = newValue
        }
    }
    private var magnification: CGFloat {
        get {
            let stored = Settings.shared.magnification
            return stored > 0 ? stored : 2.0  // Default to 2.0 if not set
        }
        set {
            Settings.shared.magnification = newValue
        }
    }
    private var currentImage: NSImage?
    private var screenFrame: NSRect = .zero
    private var captureRect: CGRect = .zero
    private var trackingArea: NSTrackingArea?

    // Change detection
    private var lastFullScreenshot: NSImage?
    private var lastChangeCheckTime: TimeInterval = 0
    private var lastCaptureTime: TimeInterval = 0
    private let changeDetectionInterval: TimeInterval = 0.1
    private let captureThrottleInterval: TimeInterval = 0.033
    private var changeDetectionTimer: Timer?

    // Radius constraints
    private let minRadius: CGFloat = 30
    private let maxRadius: CGFloat = 200
    private let radiusStep: CGFloat = 10

    // Performance optimizations
    private var lastMouseLocation: NSPoint = .zero
    private let mouseMoveThreshold: CGFloat = 3.0
    private let captureBuffer: CGFloat = 50  // Reduced buffer for sharper capture

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let screen = window?.screen {
            screenFrame = screen.frame
        }

        NSCursor.hide()
        setupTrackingArea()
        startChangeDetection()
        captureScreen()
    }

    private func startChangeDetection() {
        changeDetectionTimer = Timer.scheduledTimer(
            withTimeInterval: changeDetectionInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForScreenChanges()
        }
    }

    private func stopChangeDetection() {
        changeDetectionTimer?.invalidate()
        changeDetectionTimer = nil
    }

    private func checkForScreenChanges() {
        Task {
            guard
                let content =
                    try? await SCShareableContent.excludingDesktopWindows(
                        false,
                        onScreenWindowsOnly: true
                    ),
                let display = content.displays.first
            else { return }

            let sampleSize: CGFloat = 200
            let centerX = mouseLocation.x - screenFrame.minX
            let centerY = mouseLocation.y - screenFrame.minY

            let sampleRect = CGRect(
                x: max(0, centerX - sampleSize / 2),
                y: max(0, centerY - sampleSize / 2),
                width: min(
                    sampleSize,
                    screenFrame.width - max(0, centerX - sampleSize / 2)
                ),
                height: min(
                    sampleSize,
                    screenFrame.height - max(0, centerY - sampleSize / 2)
                )
            )

            let flippedY = screenFrame.height - sampleRect.maxY
            let screenSampleRect = CGRect(
                x: sampleRect.minX + screenFrame.minX,
                y: flippedY + screenFrame.minY,
                width: sampleRect.width,
                height: sampleRect.height
            )

            let config = SCStreamConfiguration()
            config.width = Int(sampleRect.width)
            config.height = Int(sampleRect.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.sourceRect = screenSampleRect

            var windowsToExclude: [SCWindow] = []
            if let window = self.window {
                let allWindows = content.windows
                if let magnifierWindow = allWindows.first(where: {
                    $0.windowID == CGWindowID(window.windowNumber)
                }) {
                    windowsToExclude.append(magnifierWindow)
                }
            }

            let filter = SCContentFilter(
                display: display,
                excludingWindows: windowsToExclude
            )

            do {
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let sampleImage = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )

                DispatchQueue.main.async {
                    if self.hasScreenChanged(newSample: sampleImage) {
                        self.captureScreen()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureScreenIfNeeded()
                }
            }
        }
    }

    private func hasScreenChanged(newSample: NSImage) -> Bool {
        guard let lastSample = lastFullScreenshot else {
            lastFullScreenshot = newSample
            return true
        }

        let newHash = imageHash(newSample)
        let oldHash = imageHash(lastSample)

        let hasChanged = newHash != oldHash
        if hasChanged {
            lastFullScreenshot = newSample
        }

        return hasChanged
    }

    private func imageHash(_ image: NSImage) -> Int {
        guard
            let cgImage = image.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
            )
        else { return 0 }

        let width = cgImage.width
        let height = cgImage.height
        var hash = 0

        let sampleStep = max(1, min(width, height) / 20)
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                if let pixelData = cgImage.dataProvider?.data,
                    let data = CFDataGetBytePtr(pixelData)
                {
                    let pixelIndex = (y * width + x) * 4
                    if pixelIndex < CFDataGetLength(pixelData) - 3 {
                        let r = Int(data[pixelIndex])
                        let g = Int(data[pixelIndex + 1])
                        let b = Int(data[pixelIndex + 2])
                        hash = hash &+ (r &+ g &+ b)
                    }
                }
            }
        }

        return hash
    }

    private func setupTrackingArea() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    override func mouseMoved(with event: NSEvent) {
        updateMouseLocation()
    }

    private func updateMouseLocation() {
        let newLocation = NSEvent.mouseLocation

        let distance = sqrt(
            pow(newLocation.x - lastMouseLocation.x, 2)
                + pow(newLocation.y - lastMouseLocation.y, 2)
        )
        guard distance > mouseMoveThreshold else { return }

        mouseLocation = newLocation
        lastMouseLocation = newLocation

        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY

        if event.modifierFlags.contains(.command) {
            // Change magnification when Command key is pressed
            let magnificationStep: CGFloat = 0.5
            let minMagnification: CGFloat = 1.0
            let maxMagnification: CGFloat = 5.0

            let oldMagnification = magnification

            if delta > 0 {
                magnification = min(
                    magnification + magnificationStep,
                    maxMagnification
                )
            } else if delta < 0 {
                magnification = max(
                    magnification - magnificationStep,
                    minMagnification
                )
            }

            // Trigger new capture if magnification changed
            if abs(magnification - oldMagnification) >= magnificationStep {
                captureScreen()
            }
        } else {
            // Change radius when no modifier key is pressed
            let oldRadius = magnifierRadius

            if delta > 0 {
                magnifierRadius = min(magnifierRadius + radiusStep, maxRadius)
            } else if delta < 0 {
                magnifierRadius = max(magnifierRadius - radiusStep, minRadius)
            }

            // Trigger new capture if radius changed significantly
            if abs(magnifierRadius - oldRadius) >= radiusStep {
                captureScreen()
            }
        }

        needsDisplay = true
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            cleanup()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    deinit {
        cleanup()
    }

    func cleanup() {
        stopChangeDetection()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        NSCursor.unhide()
    }

    private func captureScreenIfNeeded() {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastCaptureTime >= captureThrottleInterval else {
            return
        }
        lastCaptureTime = currentTime

        captureScreen()
    }

    private func captureScreen() {
        Task {
            guard
                let content =
                    try? await SCShareableContent.excludingDesktopWindows(
                        false,
                        onScreenWindowsOnly: true
                    ),
                let display = content.displays.first
            else { return }

            // Capture at higher resolution for sharper magnification
            let actualCaptureRadius =
                (magnifierRadius / magnification) + captureBuffer
            let captureSize = actualCaptureRadius * 2

            let centerX = mouseLocation.x - screenFrame.minX
            let centerY = mouseLocation.y - screenFrame.minY

            captureRect = CGRect(
                x: max(0, centerX - actualCaptureRadius),
                y: max(0, centerY - actualCaptureRadius),
                width: min(
                    captureSize,
                    screenFrame.width - max(0, centerX - actualCaptureRadius)
                ),
                height: min(
                    captureSize,
                    screenFrame.height - max(0, centerY - actualCaptureRadius)
                )
            )

            let flippedY = screenFrame.height - captureRect.maxY
            let screenCaptureRect = CGRect(
                x: captureRect.minX + screenFrame.minX,
                y: flippedY + screenFrame.minY,
                width: captureRect.width,
                height: captureRect.height
            )

            let config = SCStreamConfiguration()
            // Capture at 2x resolution for sharper magnification
            config.width = Int(captureRect.width * 2)
            config.height = Int(captureRect.height * 2)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.sourceRect = screenCaptureRect

            var windowsToExclude: [SCWindow] = []
            if let window = self.window {
                let allWindows = content.windows
                if let magnifierWindow = allWindows.first(where: {
                    $0.windowID == CGWindowID(window.windowNumber)
                }) {
                    windowsToExclude.append(magnifierWindow)
                }
            }

            let filter = SCContentFilter(
                display: display,
                excludingWindows: windowsToExclude
            )

            do {
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let nsImage = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )

                DispatchQueue.main.async {
                    self.currentImage = nsImage
                    self.lastCaptureTime = CACurrentMediaTime()
                    self.needsDisplay = true
                }
            } catch {
                // Silent error handling
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = currentImage else { return }

        let viewLocation = convert(mouseLocation, from: nil)
        let captureRadius = magnifierRadius / magnification

        // Fix coordinate calculation - mouse position relative to capture area
        let mouseInCaptureX =
            mouseLocation.x - screenFrame.minX - captureRect.minX
        let mouseInCaptureY =
            mouseLocation.y - screenFrame.minY - captureRect.minY

        // Correct image scale calculation
        let imageScale = image.size.width / captureRect.width

        // Center the source rect on the mouse position within the captured image
        let sourceRect = NSRect(
            x: (mouseInCaptureX * imageScale) - (captureRadius * imageScale),
            y: (mouseInCaptureY * imageScale) - (captureRadius * imageScale),
            width: captureRadius * 2 * imageScale,
            height: captureRadius * 2 * imageScale
        )

        let magnifierRect = NSRect(
            x: viewLocation.x - magnifierRadius,
            y: viewLocation.y - magnifierRadius,
            width: magnifierRadius * 2,
            height: magnifierRadius * 2
        )

        let path = NSBezierPath(ovalIn: magnifierRect)

        // Enable high-quality rendering
        NSGraphicsContext.current?.saveGraphicsState()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSGraphicsContext.current?.shouldAntialias = true

        path.addClip()

        image.draw(
            in: magnifierRect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0
        )

        NSGraphicsContext.current?.restoreGraphicsState()

        // Draw crisp border
        NSColor.white.setStroke()
        path.lineWidth = 3
        path.stroke()

        NSColor.black.withAlphaComponent(0.3).setStroke()
        let shadowPath = NSBezierPath(
            ovalIn: magnifierRect.insetBy(dx: -1, dy: -1)
        )
        shadowPath.lineWidth = 1
        shadowPath.stroke()
    }
}
