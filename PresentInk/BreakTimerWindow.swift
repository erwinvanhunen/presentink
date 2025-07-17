import Cocoa

class BreakTimerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            NotificationCenter.default.post(name: NSNotification.Name("CloseBreakTimers"), object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
