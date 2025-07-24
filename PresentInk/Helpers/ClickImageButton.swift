//
//  ClickImageButton.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-24.
//

import AppKit

class ClickImageButton: NSButton {

    required init(image: NSImage, width: CGFloat, height: CGFloat, action: Selector?, target: AnyObject?) {
        super.init(frame: .init(x: 0, y: 0, width: width, height: height))
//        super.init(frame: NSFrame(x: 0, y: 0, width: width, height: height))
        self.image = image
        self.isBordered = false
        self.bezelStyle = .regularSquare
        self.imagePosition = .imageOnly
        self.target = target
        self.action = action
        self.translatesAutoresizingMaskIntoConstraints = false
        self.setContentHuggingPriority(.required, for: .horizontal)
        self.setContentHuggingPriority(.required, for: .vertical)
        self.imageScaling = .scaleProportionallyUpOrDown
        self.widthAnchor.constraint(equalToConstant: width).isActive = true
        self.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
