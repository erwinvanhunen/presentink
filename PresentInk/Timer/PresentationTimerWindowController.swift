//
//  PresentationTimerWindowController.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-08-21.
//


// swift
import Cocoa

final class PresentationTimerWindowController: NSWindowController {
    private let screen: NSScreen
    private let timerView = PresentationTimerOverlayView()

    init(screen: NSScreen) {
        self.screen = screen

        // Default size; view autolayout keeps padding
        let size = NSSize(width: 150, height: 40)
        let frame = PresentationTimerWindowController.bottomLeftFrame(on: screen, size: size, margin: 24)

        let window = PresentationTimerWindow(screen: screen, initialFrame: frame)
        window.contentView = timerView

        // Pin view to window bounds
        timerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timerView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            timerView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            timerView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            timerView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndStart() {
        guard let window = window else { return }
        window.orderFrontRegardless()
        timerView.start()
    }

    func stopAndClose() {
        timerView.stop()
        window?.close()
    }

    private static func bottomLeftFrame(on screen: NSScreen, size: NSSize, margin: CGFloat) -> NSRect {
        let vf = screen.visibleFrame
        let origin = NSPoint(x: vf.minX + margin, y: vf.minY + margin)
        return NSRect(origin: origin, size: size)
    }
}