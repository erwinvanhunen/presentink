import Cocoa

class CountdownOverlayWindowController: NSWindowController {
    let screen: NSScreen

    init(screen: NSScreen) {
        self.screen = screen
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
        window.contentView = CountdownView()
        window.makeKeyAndOrderFront(nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func startCountdown(completion: @escaping () -> Void) {
        guard let view = window?.contentView as? CountdownView else { return }
        view.startCountdown(completion: completion)
    }

    class CountdownView: NSView {
        private var count = 3
        private var timer: Timer?
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let text = "\(count)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 200, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let size = text.size(withAttributes: attrs)
            let point = NSPoint(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2
            )
            text.draw(at: point, withAttributes: attrs)
        }
        func startCountdown(completion: @escaping () -> Void) {
            count = 3
            setNeedsDisplay(bounds)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                guard let self = self else { return }
                self.count -= 1
                self.setNeedsDisplay(self.bounds)
                if self.count == 0 {
                    t.invalidate()
                    completion()
                }
            }
        }
    }
}