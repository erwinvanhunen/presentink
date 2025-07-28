//
//  LiveCaptionsOverlayWindow.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-28.
//

// PresentInk/Captions/LiveCaptionsOverlayWindow.swift

import Cocoa

class LiveCaptionsOverlayWindow: NSWindow {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .mainMenu
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

class LiveCaptionsOverlayView: NSView {
    private var lastUpdateTime: Date?
    private let pauseInterval: TimeInterval = 1.0
    private var lastFullText: String = ""

    var captionText: String = "" {
        didSet {
            let now = Date()
            
            if let last = lastUpdateTime, now.timeIntervalSince(last) > pauseInterval {
                // Pause detected: clear previous text and show only new text
                if captionText.hasPrefix(lastFullText) {
                    let newText = String(captionText.dropFirst(lastFullText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    _captionText = newText
                } else {
                    _captionText = captionText
                }
            } else {
                // Extract only the new part of the text
             
                lastFullText = ""
                _captionText = captionText
            }
            
            lastFullText = captionText
            lastUpdateTime = now
            needsDisplay = true
        }
    }

    private var _captionText: String = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Settings.shared.liveCaptionsFontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
            .paragraphStyle: paragraphStyle,
        ]

        let lineHeight: CGFloat = 44
        let maxTextHeight: CGFloat = lineHeight * 2
        let maxTextWidth: CGFloat = bounds.width - 40

        let attributedString = NSAttributedString(
            string: _captionText,
            attributes: attributes
        )
        let textRectSize = attributedString.boundingRect(
            with: NSSize(width: maxTextWidth, height: maxTextHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        let x = (bounds.width - textRectSize.width) / 2
        let y = 40  // 40pt margin from the bottom

        let textRect = NSRect(
            x: x,
            y: CGFloat(y),
            width: textRectSize.width,
            height: textRectSize.height
        )
        attributedString.draw(in: textRect)
    }
}
