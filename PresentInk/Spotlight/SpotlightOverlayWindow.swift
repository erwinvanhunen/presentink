//
//  FlashlightOverlayWindow.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-25.
//

import Cocoa

class SpotlightOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
    }
    
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class SpotlightOverlayView: NSView {
    var mouseLocation: NSPoint = .zero
    let flashlightRadius: CGFloat = 180
    var currentRadius: CGFloat = 0
    var overlayAlpha: CGFloat = 0.7
    var trackingArea: NSTrackingArea?
    var animationTimer: Timer?
    var isClosing: Bool = false

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupTrackingArea()
        updateMouseLocation()
        
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
            self?.window?.makeFirstResponder(self)
        }
        
        startGrowAnimation()
    }

    private func startGrowAnimation() {
        currentRadius = 5
        overlayAlpha = 0.7
        let animationDuration: TimeInterval = 0.5
        let frameDuration: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(animationDuration / frameDuration)
        var currentFrame = 0

        animationTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)
            
            let easedProgress = 1.0 - pow(1.0 - progress, 3.0)
            self.currentRadius = 5 + (self.flashlightRadius - 5) * easedProgress

            self.needsDisplay = true

            if currentFrame >= totalFrames {
                self.currentRadius = self.flashlightRadius
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

        animationTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)
            
            // Fade out the dark overlay
            self.overlayAlpha = 0.7 * (1.0 - progress)

            self.needsDisplay = true

            if currentFrame >= totalFrames {
                timer.invalidate()
                NotificationCenter.default.post(name: NSNotification.Name("ClearSpotlightOverlays"), object: nil)
                
//                self.window?.close()
                
            }
        }
    }

    func closeWithAnimation() {
        animationTimer?.invalidate()
        startCloseAnimation()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            closeWithAnimation()
            return
        }
        super.keyDown(with: event)
    }

    private func setupTrackingArea() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
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
        if !isClosing {
            updateMouseLocation()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if !isClosing {
            updateMouseLocation()
        }
    }

    private func updateMouseLocation() {
        guard let window = self.window else { return }
        let globalPoint = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: globalPoint)
        self.mouseLocation = self.convert(windowPoint, from: nil)
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw dark overlay with animated alpha
        ctx.setFillColor(NSColor.black.withAlphaComponent(overlayAlpha).cgColor)
        ctx.fill(bounds)
        
        // Only draw the clear circle if not fully faded
        if overlayAlpha > 0 {
            ctx.setBlendMode(.clear)
            ctx.addEllipse(in: CGRect(
                x: mouseLocation.x - currentRadius,
                y: mouseLocation.y - currentRadius,
                width: currentRadius * 2,
                height: currentRadius * 2
            ))
            ctx.fillPath()
            ctx.setBlendMode(.normal)
        }
    }

    deinit {
        animationTimer?.invalidate()
    }
}
