//
//  RectangleSelectionOverlayController.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-23.
//


import Cocoa

class ScreenRecordRectangleController: NSWindowController, NSWindowDelegate {
    var onSelection: ((NSScreen, CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    convenience init(screen: NSScreen) {
        let window = ScreenRecordRectangleWindow(screen: screen)
        self.init(window: window)
        
        if let selectionView = window.selectionView {
            selectionView.onSelectionComplete = { [weak self] cropRect in
                guard let self = self else { return }
                self.onSelection?(screen, cropRect)
            }
            selectionView.onCancel = { [weak self] in
                guard let self = self else { return }
                self.onCancel?()
                self.close()
            }
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async {
                window.makeFirstResponder(selectionView)
            }
        }
        
        
        window.delegate = self
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.level = .screenSaver
        window?.ignoresMouseEvents = false
        
        if let selectionView = (window as? ScreenRecordRectangleWindow)?.selectionView {
               window?.makeFirstResponder(selectionView)
           }
    }
    
    func enableClickThrough() {
        window?.ignoresMouseEvents = true
    }
    
    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }
}
