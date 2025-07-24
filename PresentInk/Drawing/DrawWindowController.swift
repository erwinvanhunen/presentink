import Cocoa

class DrawWindowController: NSWindowController {
    convenience init(screen: NSScreen) {
        let screenRect = screen.visibleFrame
        let window = DrawWindow(contentRect: screenRect)
        self.init(window: window)
        let drawingView = DrawingView(frame: window.contentRect(forFrameRect: screenRect))
        drawingView.currentLineWidth = CGFloat(Settings.shared.penWidth)
        window.contentView = drawingView
        window.makeFirstResponder(drawingView)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleBlackboardMode),
            name: NSNotification.Name("ToggleBlackBoardMode"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleWhiteboardMode),
            name: NSNotification.Name("ToggleWhiteBoardMode"),
            object: nil
        )

    }
    
    @objc func toggleBlackboardMode() {
        let drawingView = window?.contentView as? DrawingView
        if(drawingView?.fullBoardMode == .black) {
            drawingView?.fullBoardMode = .none
        }
        else {
            drawingView?.fullBoardMode = .black
        }
        drawingView?.needsDisplay = true
    }
    
    @objc func toggleWhiteboardMode() {
        let drawingView = window?.contentView as? DrawingView
        if(drawingView?.fullBoardMode == .white) {
            drawingView?.fullBoardMode = .none
        }
        else {
            drawingView?.fullBoardMode = .white
        }
        drawingView?.needsDisplay = true
    }
}

class DrawWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless],
                   backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isMovableByWindowBackground = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.setFrame(contentRect, display: true)
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
    }
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}
