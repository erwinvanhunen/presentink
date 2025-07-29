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
        
        guard !_captionText.isEmpty else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Settings.shared.liveCaptionsFontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
        ]

        let horizontalMargin: CGFloat = 20
        let verticalMargin: CGFloat = 16
        let bottomMargin: CGFloat = 40
        
        // Maximum width is 70% of screen width
        let maxTextWidth = (bounds.width * 0.7) - (horizontalMargin * 2)
        
        let attributedString = NSAttributedString(string: _captionText, attributes: attributes)
        
        // Calculate the actual text size with word wrapping and unlimited height
        let textRect = attributedString.boundingRect(
            with: NSSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        
        // Calculate background rectangle dimensions
        let backgroundWidth = min(textRect.width + (horizontalMargin * 2), bounds.width * 0.7)
        let backgroundHeight = textRect.height + (verticalMargin * 2)
        
        // Center the background rectangle horizontally
        let backgroundX = (bounds.width - backgroundWidth) / 2
        let backgroundY = bottomMargin
        
        let backgroundRect = NSRect(
            x: backgroundX,
            y: backgroundY,
            width: backgroundWidth,
            height: backgroundHeight
        )
        
        // Draw background with rounded corners
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.8).setFill()
        backgroundPath.fill()
        
        // Calculate text drawing area within the background
        let textDrawRect = NSRect(
            x: backgroundRect.minX + horizontalMargin,
            y: backgroundRect.minY + verticalMargin,
            width: backgroundRect.width - (horizontalMargin * 2),
            height: backgroundRect.height - (verticalMargin * 2)
        )
        
        // Draw the text
        attributedString.draw(in: textDrawRect)
    }
}
