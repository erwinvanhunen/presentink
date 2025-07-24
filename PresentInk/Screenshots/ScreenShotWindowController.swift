//
//  ScreenShotController.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-11.
//

import Cocoa

class ScreenShotWindowController: NSWindowController, NSWindowDelegate {
    convenience init(screen: NSScreen) {
        let window = ScreenShotWindow(screen: screen)
        self.init(window: window)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        // Remove subviews or perform other cleanup here
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
