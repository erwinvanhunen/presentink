import Cocoa
import ScreenCaptureKit
import AppKit


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
}

import Cocoa
import ScreenCaptureKit

class MagnifierOverlayView: NSView, SCStreamOutput {
    private var ellipseRadius: CGFloat
    {
        get { Settings.shared.magnifierRadius }
        set { Settings.shared.magnifierRadius = newValue }
    }
    private var capturedImage: NSImage?
    private var timer: Timer?
    private var stream: SCStream?
    private var display: SCDisplay?
    private var filter: SCContentFilter?
    private var lastScreen: NSScreen?
    private var zoomFactor: CGFloat {
        get { Settings.shared.magnification }
        set { Settings.shared.magnification = newValue }
    }
    
    
    override func viewDidMoveToWindow() {
           super.viewDidMoveToWindow()
           
           setupScreenCapture()
           startScreenshotTimer()
           NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
               self?.handleMouseMoved()
               self?.needsDisplay = true
               return event
           }
           
           NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
               guard let self = self else { return event }
               if event.modifierFlags.contains(.command) {
                   // Change zoom factor with Command + scroll
                   let minZoom: CGFloat = 1.0
                   let maxZoom: CGFloat = 5.0
                   self.zoomFactor = min(max(self.zoomFactor + event.deltaY * 0.1, minZoom), maxZoom)
                   Settings.shared.magnification = self.zoomFactor
               } else {
                   // Change ellipse radius
                   let minRadius: CGFloat = 40
                   let maxRadius: CGFloat = 300
                   self.ellipseRadius = min(max(self.ellipseRadius + event.deltaY * 5, minRadius), maxRadius)
                   Settings.shared.magnifierRadius = self.ellipseRadius
               }
               self.needsDisplay = true
               return event
           }
       }
    
    private func handleMouseMoved() {
           let mouseLocation = NSEvent.mouseLocation
           if let newScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
               if newScreen != lastScreen {
                   lastScreen = newScreen
                   updateOverlayWindowFrame(for: newScreen)
                   setupScreenCapture()
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
        guard let _ = window?.screen else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
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
        guard let screen = lastScreen ?? window?.screen else { return }
              lastScreen = screen
        Task {
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            // Find PresentInk windows to exclude
            let presentInkWindows = content?.windows.filter {
                $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
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
            self.filter = SCContentFilter(display: display, excludingWindows: presentInkWindows)
            let config = SCStreamConfiguration()
            config.width = Int(display.width * 2)
            config.height = Int(display.height * 2)
            self.stream = SCStream(filter: self.filter!, configuration: config, delegate: nil)
            try? self.stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.main)
            try? await self.stream?.startCapture()
        }
    }
    
    private func startScreenshotTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        self.capturedImage = image
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let window = window,
              let image = capturedImage,
              image.size.width > 0, image.size.height > 0 else { return }

        let globalMouse = NSEvent.mouseLocation
        let screenFrame = window.screen?.frame ?? .zero
        let mouseOnScreen = CGPoint(x: globalMouse.x - screenFrame.origin.x, y: globalMouse.y - screenFrame.origin.y)

        // Map mouse position to image coordinates (image is double resolution)
        let imageMouse = CGPoint(x: mouseOnScreen.x * 2, y: mouseOnScreen.y * 2)

        // Crop area size shrinks as zoom increases
        let cropSize = (ellipseRadius * 2) / zoomFactor
        let cropRect = NSRect(
            x: imageMouse.x - cropSize / 2,
            y: imageMouse.y - cropSize / 2,
            width: cropSize,
            height: cropSize
        )

        let ellipseRect = NSRect(
            x: mouseOnScreen.x - ellipseRadius,
            y: mouseOnScreen.y - ellipseRadius,
            width: ellipseRadius * 2,
            height: ellipseRadius * 2
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
