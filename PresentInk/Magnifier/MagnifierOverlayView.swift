import AppKit
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
        self.level = .screenSaver
        self.ignoresMouseEvents = true
        self.hasShadow = false
    }
    
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class MagnifierOverlayView: NSView, SCStreamOutput {
    private var ellipseRadius: CGFloat
    {
        get { Settings.shared.magnifierRadius }
        set { Settings.shared.magnifierRadius = newValue }
    }
    var currentRadius: CGFloat = 0
    private var capturedImage: NSImage?
    private var timer: Timer?
    private var stream: SCStream?
    private var display: SCDisplay?
    private var filter: SCContentFilter?
    private var lastScreen: NSScreen?
    var isClosing: Bool = false

    private var zoomFactor: CGFloat {
        get { Settings.shared.magnification }
        set { Settings.shared.magnification = newValue }
    }

    var animationTimer: Timer?
    
    
    override var acceptsFirstResponder: Bool {
        return true
    }


    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

//        NSCursor.hide()
        setupScreenCapture()
        startScreenshotTimer()
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) {
            [weak self] event in
            self?.handleMouseMoved()
            self?.needsDisplay = true
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            guard let self = self else { return event }
            guard !isClosing else { return event }
            if event.modifierFlags.contains(.command) {
                // Change zoom factor with Command + scroll
                let minZoom: CGFloat = 1.0
                let maxZoom: CGFloat = 5.0
                self.zoomFactor = min(
                    max(self.zoomFactor + event.deltaY * 0.1, minZoom),
                    maxZoom
                )
                Settings.shared.magnification = self.zoomFactor
            } else {
                // Change ellipse radius
                let minRadius: CGFloat = 40
                let maxRadius: CGFloat = 300
                self.ellipseRadius = min(
                    max(self.ellipseRadius + event.deltaY * 5, minRadius),
                    maxRadius
                )
                currentRadius = ellipseRadius
                Settings.shared.magnifierRadius = self.ellipseRadius
            }
            self.needsDisplay = true
            return event
        }

        startGrowAnimation()
    }

    private func startGrowAnimation() {
        currentRadius = 5
        let animationDuration: TimeInterval = 0.5
        let frameDuration: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(animationDuration / frameDuration)
        var currentFrame = 0

        animationTimer = Timer.scheduledTimer(
            withTimeInterval: frameDuration,
            repeats: true
        ) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)

            let easedProgress = 1.0 - pow(1.0 - progress, 3.0)
            self.currentRadius = 5 + (self.ellipseRadius - 5) * easedProgress

            DispatchQueue.main.async {
                self.needsDisplay = true
            }

            if currentFrame >= totalFrames {
                self.currentRadius = self.ellipseRadius
                timer.invalidate()
                self.animationTimer = nil
            }
        }
    }

    private func startCloseAnimation() {
        isClosing = true
        let animationDuration: TimeInterval = 0.3
        let frameDuration: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(animationDuration / frameDuration)
        var currentFrame = 0

        animationTimer = Timer.scheduledTimer(
            withTimeInterval: frameDuration,
            repeats: true
        ) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)

            // Fade out the dark overlay
            self.currentRadius = self.ellipseRadius * (1.0 - progress)
            self.needsDisplay = true

            if currentFrame >= totalFrames {
//                window?.ignoresMouseEvents = false
                NSCursor.unhide()
                
                timer.invalidate()
                NotificationCenter.default.post(
                    name: NSNotification.Name("ClearMagnifierOverlays"),
                    object: nil
                )
            }
        }
    }

    func closeWithAnimation() {
        animationTimer?.invalidate()
        startCloseAnimation()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape key
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleMagnifierOverlays"),
                object: nil
            )
            return
        }
        super.keyDown(with: event)
    }

    private func handleMouseMoved() {
        if !isClosing {
            let mouseLocation = NSEvent.mouseLocation
            if let newScreen = NSScreen.screens.first(where: {
                NSMouseInRect(mouseLocation, $0.frame, false)
            }) {
                if newScreen != lastScreen {
                    lastScreen = newScreen
                    updateOverlayWindowFrame(for: newScreen)
                    setupScreenCapture()
                }
            }
        }
    }

    private func updateOverlayWindowFrame(for screen: NSScreen) {
        window?.setFrame(screen.frame, display: true)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        NSCursor.hide()
    }

    private func waitForScreenAndSetupCapture() {
        guard window?.screen != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                [weak self] in
                self?.waitForScreenAndSetupCapture()
            }
            return
        }
        setupScreenCapture()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            NSCursor.unhide()
            timer?.invalidate()
            timer = nil
            stream?.stopCapture()
            stream = nil
        }
    }
    
    private func setupScreenCapture() {
        if isClosing { return }
        guard let screen = lastScreen ?? window?.screen else { return }
        lastScreen = screen
        Task {
            let content = try? await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            // Find PresentInk windows to exclude
            let presentInkWindows =
                content?.windows.filter {
                    $0.owningApplication?.bundleIdentifier
                        == Bundle.main.bundleIdentifier
                } ?? []

            let screenNumber =
                window?.screen?.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber
            guard
                let display = content?.displays.first(where: {
                    $0.displayID == screenNumber?.uint32Value
                })
            else {
                print("Could not find matching display")
                return
            }

            self.display = display
            self.filter = SCContentFilter(
                display: display,
                excludingWindows: presentInkWindows
            )
            let config = SCStreamConfiguration()
            config.width = Int(display.width * 2)
            config.height = Int(display.height * 2)
            self.stream = SCStream(
                filter: self.filter!,
                configuration: config,
                delegate: nil
            )
            try? self.stream?.addStreamOutput(
                self,
                type: .screen,
                sampleHandlerQueue: DispatchQueue.main
            )
            try? await self.stream?.startCapture()
        }
    }

    private func startScreenshotTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            self?.needsDisplay = true
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
            let pixelBuffer = sampleBuffer.imageBuffer
        else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        self.capturedImage = image
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let window = window,
            let image = capturedImage,
            image.size.width > 0, image.size.height > 0
        else { return }

        let globalMouse = NSEvent.mouseLocation
        let screenFrame = window.screen?.frame ?? .zero
        let mouseOnScreen = CGPoint(
            x: globalMouse.x - screenFrame.origin.x,
            y: globalMouse.y - screenFrame.origin.y
        )

        // Map mouse position to image coordinates (image is double resolution)
        let imageMouse = CGPoint(x: mouseOnScreen.x * 2, y: mouseOnScreen.y * 2)

        // Crop area size shrinks as zoom increases
        let cropSize = (currentRadius * 2) / zoomFactor
        let cropRect = NSRect(
            x: imageMouse.x - cropSize / 2,
            y: imageMouse.y - cropSize / 2,
            width: cropSize,
            height: cropSize
        )

        let ellipseRect = NSRect(
            x: mouseOnScreen.x - currentRadius,
            y: mouseOnScreen.y - currentRadius,
            width: currentRadius * 2,
            height: currentRadius * 2
        )

        let path = NSBezierPath(ovalIn: ellipseRect)
        path.addClip()
        NSColor.black.setFill()
        path.fill()

        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(
            in: ellipseRect,
            from: cropRect,
            operation: .copy,
            fraction: 1.0
        )

        NSColor.white.setStroke()
        path.lineWidth = 3
        path.stroke()
    }
}
