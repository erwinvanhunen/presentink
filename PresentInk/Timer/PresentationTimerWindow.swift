// swift
import Cocoa

final class PresentationTimerWindow: NSWindow {
    init(screen: NSScreen, initialFrame: NSRect) {
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        // Ensure it sits at the requested position
        setFrame(initialFrame, display: false)

        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true  // do not interfere with desktop/apps
        hasShadow = true
        level = .mainMenu
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        isReleasedWhenClosed = false
    }
}
