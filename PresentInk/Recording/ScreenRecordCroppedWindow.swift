import Cocoa

class ScreenRecordCroppedWindow: NSWindow {
    var selectionView: ScreenRecordCroppedView?
    
    init(screen: NSScreen) {
        let screenRect = screen.frame
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        
        // Move window to the correct screen
        self.setFrame(screenRect, display: true)
        
        selectionView = ScreenRecordCroppedView(frame: screenRect, screen: screen)
        self.contentView = selectionView
        
        DispatchQueue.main.async {
            self.makeFirstResponder(self.selectionView)
        }
    }
  
    override var canBecomeKey: Bool { true }
    
    override var acceptsFirstResponder: Bool { true }
 
}
