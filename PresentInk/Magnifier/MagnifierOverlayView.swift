import ScreenCaptureKit
import AVFoundation
import Cocoa

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
        self.ignoresMouseEvents = false // Accept mouse events
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true // Track mouse movement
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
     private var magnifierRadius: CGFloat = 80
     private let magnification: CGFloat = 2.0
     private var currentImage: NSImage?
     private var screenFrame: NSRect = .zero
     private var captureRect: CGRect = .zero
     private var trackingArea: NSTrackingArea?
    
    private var lastCaptureTime: TimeInterval = 0
       private let captureThrottleInterval: TimeInterval = 0.033 // 30fps for better performance
       
       // Radius constraints
       private let minRadius: CGFloat = 30
       private let maxRadius: CGFloat = 200
       private let radiusStep: CGFloat = 10
       
       // Performance optimizations
       private var lastMouseLocation: NSPoint = .zero
       private let mouseMoveThreshold: CGFloat = 3.0
       
       // Smaller capture area for better performance
       private let captureBuffer: CGFloat = 100
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let screen = window?.screen {
            screenFrame = screen.frame
        }
        
        // Hide cursor in the magnifier view
        NSCursor.hide()
        
        setupTrackingArea()
        captureScreen()
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
           
           // Only update if mouse moved significantly
           let distance = sqrt(pow(newLocation.x - lastMouseLocation.x, 2) + pow(newLocation.y - lastMouseLocation.y, 2))
           guard distance > mouseMoveThreshold else { return }
           
           mouseLocation = newLocation
           lastMouseLocation = newLocation
           
           captureScreenIfNeeded()
       }
    
    override func scrollWheel(with event: NSEvent) {
            // Only change radius if Command key is pressed
//          Â  guard event.modifierFlags.contains(.command) else { return }
            
            let delta = event.scrollingDeltaY
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
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        // Show cursor when cleaning up
        NSCursor.unhide()
    }


    private func captureScreenIfNeeded() {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastCaptureTime >= captureThrottleInterval else { return }
        lastCaptureTime = currentTime
        
        captureScreen()
    }

    private func captureScreen() {
        Task {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
                  let display = content.displays.first else { return }

            // Calculate smaller capture area
            let actualCaptureRadius = (magnifierRadius / magnification) + captureBuffer
            let captureSize = actualCaptureRadius * 2
            
            let centerX = mouseLocation.x - screenFrame.minX
            let centerY = mouseLocation.y - screenFrame.minY
            
            // Store the logical capture rect for coordinate mapping
            captureRect = CGRect(
                x: max(0, centerX - actualCaptureRadius),
                y: max(0, centerY - actualCaptureRadius),
                width: min(captureSize, screenFrame.width - max(0, centerX - actualCaptureRadius)),
                height: min(captureSize, screenFrame.height - max(0, centerY - actualCaptureRadius))
            )
            
            // For ScreenCaptureKit, we need to flip Y coordinate
            let flippedY = screenFrame.height - captureRect.maxY
            let screenCaptureRect = CGRect(
                x: captureRect.minX + screenFrame.minX,
                y: flippedY + screenFrame.minY,
                width: captureRect.width,
                height: captureRect.height
            )
            
            let config = SCStreamConfiguration()
            config.width = Int(captureRect.width)
            config.height = Int(captureRect.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.sourceRect = screenCaptureRect

            var windowsToExclude: [SCWindow] = []
            if let window = self.window {
                let allWindows = content.windows
                if let magnifierWindow = allWindows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) {
                    windowsToExclude.append(magnifierWindow)
                }
            }

            let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)
            
            do {
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                
                DispatchQueue.main.async {
                    self.currentImage = nsImage
                    self.needsDisplay = true
                }
            } catch {
                // Silent error handling to prevent logging spam
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = currentImage else { return }
        
        let viewLocation = convert(mouseLocation, from: nil)
        let captureRadius = magnifierRadius / magnification
        
        // Calculate source rect relative to the captured image
        let mouseInCaptureX = mouseLocation.x - screenFrame.minX - captureRect.minX
        let mouseInCaptureY = mouseLocation.y - screenFrame.minY - captureRect.minY
        
        let imageScale = image.size.width / captureRect.width
        
        let sourceRect = NSRect(
            x: (mouseInCaptureX - captureRadius) * imageScale,
            y: (mouseInCaptureY - captureRadius) * imageScale,
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
        
        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        
        image.draw(
            in: magnifierRect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0
        )
        
        NSGraphicsContext.current?.restoreGraphicsState()
        
        // Draw border
        NSColor.white.setStroke()
        path.lineWidth = 3
        path.stroke()
        
        // Shadow
        NSColor.black.withAlphaComponent(0.3).setStroke()
        let shadowPath = NSBezierPath(ovalIn: magnifierRect.insetBy(dx: -1, dy: -1))
        shadowPath.lineWidth = 1
        shadowPath.stroke()
    }
}
