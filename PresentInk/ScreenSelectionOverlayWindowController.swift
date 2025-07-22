import Cocoa

class ScreenSelectionOverlayWindowController: NSWindowController {
    let screenIndex: Int
    let screen: NSScreen
    var onKeyPress: ((Int) -> Void)?

    init(screen: NSScreen, index: Int) {
        self.screen = screen
        self.screenIndex = index
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        window.contentView = OverlayView(index: index)
        window.makeKeyAndOrderFront(nil)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let number = Int(event.characters ?? ""), number == index {
                self?.onKeyPress?(number)
                return nil
            }
            return event
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    class OverlayView: NSView {
        let index: Int
        init(index: Int) {
            self.index = index
            super.init(frame: .zero)
            wantsLayer = true
            layer?.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5).cgColor
        }
        required init?(coder: NSCoder) { fatalError() }
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let number = "\(index)"
            let message = "Press \(index) to record this screen"
            let numberAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 200, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let messageAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 40, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let numberSize = number.size(withAttributes: numberAttrs)
            let messageSize = message.size(withAttributes: messageAttrs)
            let numberPoint = NSPoint(
                x: (bounds.width - numberSize.width) / 2,
                y: (bounds.height - numberSize.height) / 2 + 60
            )
            let messagePoint = NSPoint(
                x: (bounds.width - messageSize.width) / 2,
                y: numberPoint.y - messageSize.height - 40
            )
            number.draw(at: numberPoint, withAttributes: numberAttrs)
            message.draw(at: messagePoint, withAttributes: messageAttrs)
        }
        override func resizeSubviews(withOldSize oldSize: NSSize) {
            setNeedsDisplay(bounds)
        }
    }
}