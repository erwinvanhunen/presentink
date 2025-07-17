//
//  SidebarHoverButton.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-10.
//

import Cocoa

class SidebarHoverButton: NSButton {
    private var hover = false {
        didSet { updateBackground() }
    }
    override var state: NSControl.StateValue {
        didSet { updateBackground() }
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }
    private var tracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking { removeTrackingArea(tracking) }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect,
        ]
        tracking = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) {
        hover = true
    }
    override func mouseExited(with event: NSEvent) {
        hover = false
    }
    private func updateBackground() {
        if state == .on {
            layer?.backgroundColor =
                NSColor(calibratedWhite: 1, alpha: 0.16).cgColor
        } else if hover {
            layer?.backgroundColor =
                NSColor(calibratedWhite: 1, alpha: 0.08).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
