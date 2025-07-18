import Cocoa

class DrawingView: NSView, NSTextFieldDelegate {
    var paths: [(PathType, NSColor, CGFloat)] = []
    var currentPath: NSBezierPath?
    var currentColor: NSColor = .red
    var currentLineWidth: CGFloat = 4
    var isDrawingStraightLine = false
    var startPoint: NSPoint?
    var straightLinePreviewEndPoint: NSPoint?
    var arrowPreviewEndPoint: NSPoint?
    var rectanglePreviewEndPoint: NSPoint?
    var drawMode: DrawMode = .freehand
    var penCursor: NSCursor?
    var textField: NSTextField?
    var textContainer: NSView?
    var textFontSize: CGFloat = 12
    var textFieldOrigin: NSPoint?
    var isEditingText = false
    var committedTexts: [(NSAttributedString, NSPoint)] = []
    var textDragOffset: NSPoint = NSPoint.zero
    var fullBoardMode: FullBoardMode = .none
    enum DrawMode {
        case straightLine
        case freehand
        case arrow
        case rectangle
        case ellipse
        case centeredEllipse
        case text
        case marker
    }

    enum FullBoardMode {
        case none
        case white
        case black
    }
    enum PathType {
        case normal(NSBezierPath)
        case arrow(start: NSPoint, end: NSPoint)
        case text(NSAttributedString, NSPoint)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { return true }
    override func flagsChanged(with event: NSEvent) {
        updateCursorForModifiers(event.modifierFlags)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isEditingText, let container = textContainer {
            let borderRect = container.frame
            addCursorRect(borderRect, cursor: NSCursor.openHand)
        } else if let penCursor = penCursor {
            addCursorRect(self.bounds, cursor: penCursor)
            penCursor.set()
        } else {
            addCursorRect(self.bounds, cursor: .arrow)
            NSCursor.arrow.set()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect,
        ]
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func scrollWheel(with event: NSEvent) {
        if isEditingText {
            if event.deltaY > 0 {
                textFontSize += 1
            } else if event.deltaY < 0 {
                textFontSize = max(12, textFontSize - 1)
            }
            updateTextFieldFont()
        } else {
            if event.deltaY > 0 {
                currentLineWidth = min(currentLineWidth + 1, 24)
            } else if event.deltaY < 0 {
                currentLineWidth = max(currentLineWidth - 1, 1)
            }
            Settings.shared.penWidth = Int(currentLineWidth)
            updateCursorForModifiers(event.modifierFlags)
            penCursor?.set()
            NSCursor.setHiddenUntilMouseMoves(false)
            needsDisplay = true
        }
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursorForModifiers(event.modifierFlags)
        penCursor?.set()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateCursorForModifiers(NSEvent.ModifierFlags())
        penCursor?.set()
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursorForModifiers(event.modifierFlags)
        penCursor?.set()
    }

    override func mouseDown(with event: NSEvent) {
        if isEditingText, let container = textContainer {
            let point = convert(event.locationInWindow, from: nil)
            // Calculate offset from click point to container origin
            textDragOffset = NSPoint(
                x: point.x - container.frame.origin.x,
                y: point.y - container.frame.origin.y
            )
        } else {
            startPoint = convert(event.locationInWindow, from: nil)
            currentPath = NSBezierPath()
            currentPath?.move(to: startPoint!)
            straightLinePreviewEndPoint = nil
            arrowPreviewEndPoint = nil
            rectanglePreviewEndPoint = nil
            drawMode = .freehand
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isEditingText, let container = textContainer {
            let point = convert(event.locationInWindow, from: nil)
            // Apply the offset to maintain anchor point
            let newOrigin = NSPoint(
                x: point.x - textDragOffset.x,
                y: point.y - textDragOffset.y
            )
            textFieldOrigin = newOrigin
            container.setFrameOrigin(newOrigin)
        } else {
            let point = convert(event.locationInWindow, from: nil)
            let mods = event.modifierFlags

            if mods.contains(.control) {
                drawMode = .marker
                straightLinePreviewEndPoint = nil
                arrowPreviewEndPoint = nil
                rectanglePreviewEndPoint = nil
                if currentPath == nil {
                    currentPath = NSBezierPath()
                    currentPath?.move(to: point)
                } else {
                    currentPath?.line(to: point)
                }
                needsDisplay = true
            } else if mods.contains(.option) && mods.contains(.shift),
                startPoint != nil
            {
                drawMode = .centeredEllipse
                rectanglePreviewEndPoint = point
                straightLinePreviewEndPoint = nil
                arrowPreviewEndPoint = nil
                needsDisplay = true
            } else if mods.contains(.option), startPoint != nil {
                drawMode = .ellipse
                rectanglePreviewEndPoint = point
                straightLinePreviewEndPoint = nil
                arrowPreviewEndPoint = nil
                needsDisplay = true
            } else if mods.contains(.command) && mods.contains(.shift),
                startPoint != nil
            {
                drawMode = .arrow
                arrowPreviewEndPoint = point
                straightLinePreviewEndPoint = nil
                rectanglePreviewEndPoint = nil
                needsDisplay = true
            } else if mods.contains(.command), startPoint != nil {
                drawMode = .rectangle
                rectanglePreviewEndPoint = point
                straightLinePreviewEndPoint = nil
                arrowPreviewEndPoint = nil
                needsDisplay = true
            } else if mods.contains(.shift), startPoint != nil {
                drawMode = .straightLine
                straightLinePreviewEndPoint = point
                arrowPreviewEndPoint = nil
                rectanglePreviewEndPoint = nil
                needsDisplay = true
            } else {
                drawMode = .freehand
                straightLinePreviewEndPoint = nil
                arrowPreviewEndPoint = nil
                rectanglePreviewEndPoint = nil
                currentPath?.line(to: point)
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch drawMode {
        case .marker:
            if let path = currentPath {
                // Use a semi-transparent color and wider line width
                let markerColor = currentColor.withAlphaComponent(0.3)
                let markerWidth = max(12, currentLineWidth * 2)
                paths.append((.normal(path), markerColor, markerWidth))
            }

        case .ellipse:
            if let start = startPoint, let end = rectanglePreviewEndPoint {
                let rect = NSRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                let ellipsePath = NSBezierPath(ovalIn: rect)
                paths.append(
                    (.normal(ellipsePath), currentColor, currentLineWidth)
                )
                rectanglePreviewEndPoint = nil
            }
        case .centeredEllipse:
            if let center = startPoint, let end = rectanglePreviewEndPoint {
                let dx = end.x - center.x
                let dy = end.y - center.y
                let rect = NSRect(
                    x: center.x - abs(dx),
                    y: center.y - abs(dy),
                    width: abs(dx) * 2,
                    height: abs(dy) * 2
                )
                let ellipsePath = NSBezierPath(ovalIn: rect)
                paths.append(
                    (.normal(ellipsePath), currentColor, currentLineWidth)
                )
                rectanglePreviewEndPoint = nil
            }
        case .arrow:
            if let start = startPoint, let arrowEnd = arrowPreviewEndPoint {
                paths.append(
                    (
                        .arrow(start: start, end: arrowEnd), currentColor,
                        currentLineWidth
                    )
                )
                arrowPreviewEndPoint = nil
            }
        case .straightLine:
            if let start = startPoint,
                let previewEnd = straightLinePreviewEndPoint
            {
                currentPath?.removeAllPoints()
                currentPath?.move(to: start)
                currentPath?.line(to: previewEnd)
                if let path = currentPath {
                    paths.append(
                        (.normal(path), currentColor, currentLineWidth)
                    )
                }
                straightLinePreviewEndPoint = nil
            }
        case .rectangle:
            if let start = startPoint, let rectEnd = rectanglePreviewEndPoint {
                let rect = NSRect(
                    x: min(start.x, rectEnd.x),
                    y: min(start.y, rectEnd.y),
                    width: abs(rectEnd.x - start.x),
                    height: abs(rectEnd.y - start.y)
                )
                let rectPath = NSBezierPath(rect: rect)
                paths.append(
                    (.normal(rectPath), currentColor, currentLineWidth)
                )
                rectanglePreviewEndPoint = nil
            }
        case .freehand:
            if let path = currentPath {
                paths.append((.normal(path), currentColor, currentLineWidth))
            }
        case .text:
            break
        }
        currentPath = nil
        startPoint = nil
        drawMode = .freehand
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if fullBoardMode != .none {

            if fullBoardMode == .black {
                NSColor.black.setFill()
                bounds.fill()
            }
            if fullBoardMode == .white {

                NSColor.white.setFill()
                bounds.fill()
            }
        }
        for (pathType, color, width) in paths {
            color.set()
            switch pathType {
            case .normal(let path):
                path.lineWidth = width
                path.stroke()
            case .arrow(let start, let end):
                let arrowPath = NSBezierPath()
                arrowPath.lineWidth = width
                drawArrow(
                    from: start,
                    to: end,
                    in: arrowPath,
                    width: width,
                    fillColor: color
                )
                arrowPath.stroke()
            case .text(let attrString, let origin):
                attrString.draw(at: origin)
            }
        }

        if(drawMode == .marker)
        {
            currentColor.withAlphaComponent(0.3).set()
            currentPath?.lineWidth = max(12, currentLineWidth * 2)
        } else {
            currentColor.set()
            currentPath?.lineWidth = currentLineWidth
        }
        currentPath?.stroke()

        let previewColor = currentColor.withAlphaComponent(0.7)

        // Draw preview paths (straight line, arrow, rectangle, ellipse)
        if drawMode == .straightLine, let start = startPoint,
            let previewEnd = straightLinePreviewEndPoint
        {
            let previewPath = NSBezierPath()
            previewPath.move(to: start)
            previewPath.line(to: previewEnd)
            previewPath.lineWidth = max(1, min(currentLineWidth, 24))
            previewColor.setStroke()
            previewPath.stroke()
        }

        if drawMode == .arrow, let start = startPoint,
            let arrowEnd = arrowPreviewEndPoint
        {
            let arrowPath = NSBezierPath()
            drawArrow(
                from: start,
                to: arrowEnd,
                in: arrowPath,
                width: max(1, min(currentLineWidth, 24)),
                fillColor: previewColor
            )
            arrowPath.lineWidth = max(1, min(currentLineWidth, 24))
            previewColor.setStroke()
            arrowPath.stroke()
        }

        if drawMode == .rectangle, let start = startPoint,
            let rectEnd = rectanglePreviewEndPoint
        {
            let rect = NSRect(
                x: min(start.x, rectEnd.x),
                y: min(start.y, rectEnd.y),
                width: abs(rectEnd.x - start.x),
                height: abs(rectEnd.y - start.y)
            )
            let rectPath = NSBezierPath(rect: rect)
            rectPath.lineWidth = max(1, min(currentLineWidth, 24))
            previewColor.setStroke()
            rectPath.stroke()
        }

        if drawMode == .ellipse || drawMode == .centeredEllipse,
            let start = startPoint, let end = rectanglePreviewEndPoint
        {
            let rect: NSRect
            if drawMode == .ellipse {
                rect = NSRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
            } else {
                let dx = end.x - start.x
                let dy = end.y - start.y
                rect = NSRect(
                    x: start.x - abs(dx),
                    y: start.y - abs(dy),
                    width: abs(dx) * 2,
                    height: abs(dy) * 2
                )
            }
            let ellipsePath = NSBezierPath(ovalIn: rect)
            ellipsePath.lineWidth = max(1, min(currentLineWidth, 24))
            previewColor.setStroke()
            ellipsePath.stroke()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape key
            if isEditingText {
                cancelTextField()
                return
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("ExitDrawingMode"),
                object: nil
            )
            return
        }
        if event.keyCode == 49 { // Space bar
                if let screen = window?.screen ?? NSScreen.main {
                    let center = CGPoint(
                        x: screen.frame.midX,
                        y: screen.frame.midY
                    )
                    CGWarpMouseCursorPosition(center)
                }
                return
            }
        if event.modifierFlags.contains(.command),
            event.charactersIgnoringModifiers?.lowercased() == "z"
        {
            if !paths.isEmpty {
                paths.removeLast()
                needsDisplay = true
            }
            return
        }

        if isEditingText {
            switch event.keyCode {
            case 126:  // Up arrow
                textFontSize += 1
                updateTextFieldFont()
                return
            case 125:  // Down arrow
                textFontSize = max(12, textFontSize - 1)
                updateTextFieldFont()
                return
            default:
                break
            }
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "r":
            currentColor = .red
            updateCursorForModifiers(event.modifierFlags)
            NotificationCenter.default.post(
                name: NSNotification.Name("DrawingColorChanged"),
                object: currentColor
            )
            Settings.shared.defaultColor = currentColor
        case "g":
            currentColor = .green
            updateCursorForModifiers(event.modifierFlags)
            NotificationCenter.default.post(
                name: NSNotification.Name("DrawingColorChanged"),
                object: currentColor
            )
            Settings.shared.defaultColor = currentColor
        case "b":
            currentColor = .blue
            updateCursorForModifiers(event.modifierFlags)
            NotificationCenter.default.post(
                name: NSNotification.Name("DrawingColorChanged"),
                object: currentColor
            )
            Settings.shared.defaultColor = currentColor
        case "y":
            currentColor = .yellow
            updateCursorForModifiers(event.modifierFlags)
            NotificationCenter.default.post(
                name: NSNotification.Name("DrawingColorChanged"),
                object: currentColor
            )
            Settings.shared.defaultColor = currentColor
        case "o":
            currentColor = .orange
            updateCursorForModifiers(event.modifierFlags)
            NotificationCenter.default.post(
                name: NSNotification.Name("DrawingColorChanged"),
                object: currentColor
            )
            Settings.shared.defaultColor = currentColor
        case "p":
            currentColor = .magenta
            updateCursorForModifiers(event.modifierFlags)
            NotificationCenter.default.post(
                name: NSNotification.Name("DrawingColorChanged"),
                object: currentColor
            )
            Settings.shared.defaultColor = currentColor
        case "e":
            paths = []
            needsDisplay = true
        case "t":
            drawMode = .text
            isEditingText = true
            textFontSize = max(12, currentLineWidth * 2)
            let mouseLoc =
                window?.mouseLocationOutsideOfEventStream
                ?? NSPoint(x: bounds.midX, y: bounds.midY)
            let viewLoc = convert(mouseLoc, from: nil)
            showTextField(at: viewLoc)
        case "w":
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleWhiteBoardMode"),
                object: "self"
            )
        case "k":
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleBlackBoardMode"),
                object: self
            )
        default:
            if !isEditingText {
                if event.keyCode == 126 {  // Up arrow
                    currentLineWidth = min(currentLineWidth + 1, 24)
                    Settings.shared.penWidth = Int(currentLineWidth)
                    updateCursorForModifiers(event.modifierFlags)
                    needsDisplay = true
                } else if event.keyCode == 125 {  // Down arrow
                    currentLineWidth = max(currentLineWidth - 1, 1)
                    Settings.shared.penWidth = Int(currentLineWidth)
                    updateCursorForModifiers(event.modifierFlags)
                    needsDisplay = true
                } else {
                    super.keyDown(with: event)
                }
            }
        }
    }

    func drawArrow(
        from start: NSPoint,
        to end: NSPoint,
        in path: NSBezierPath,
        width: CGFloat,
        fillColor: NSColor? = nil
    ) {
        // Arrowhead size scales with pen width
        let arrowHeadLength: CGFloat = max(12, width * 3)
        let arrowHeadWidth: CGFloat = max(8, width * 2.5)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0.0 else { return }

        let ux = dx / length
        let uy = dy / length

        // Base of the arrowhead
        let baseX = end.x - arrowHeadLength * ux
        let baseY = end.y - arrowHeadLength * uy
        let basePoint = NSPoint(x: baseX, y: baseY)

        // Draw the arrow shaft (stop at base of arrowhead)
        path.move(to: start)
        path.line(to: basePoint)

        // Perpendicular vector
        let perpX = -uy
        let perpY = ux

        // Points of the triangle
        let left = NSPoint(
            x: baseX + (arrowHeadWidth / 2) * perpX,
            y: baseY + (arrowHeadWidth / 2) * perpY
        )
        let right = NSPoint(
            x: baseX - (arrowHeadWidth / 2) * perpX,
            y: baseY - (arrowHeadWidth / 2) * perpY
        )

        // Draw solid arrowhead
        let arrowHead = NSBezierPath()
        arrowHead.move(to: end)
        arrowHead.line(to: left)
        arrowHead.line(to: right)
        arrowHead.close()
        (fillColor ?? currentColor).setFill()
        arrowHead.fill()
    }

    func updateCursor() {
        let diameter = max(8, min(currentLineWidth, 48))
        let size = NSSize(width: diameter + 4, height: diameter + 4)
        let image = NSImage(size: size)
        image.lockFocus()
        currentColor.setFill()
        let circleRect = NSRect(x: 2, y: 2, width: diameter, height: diameter)
        NSBezierPath(ovalIn: circleRect).fill()
        image.unlockFocus()

        let hotSpot = NSPoint(x: size.width / 2, y: size.height / 2)
        penCursor = NSCursor(image: image, hotSpot: hotSpot)
        self.discardCursorRects()
        self.window?.invalidateCursorRects(for: self)
    }

    func updateCursorForModifiers(_ modifiers: NSEvent.ModifierFlags) {
        currentLineWidth = CGFloat(Settings.shared.penWidth)
        let cursor: NSCursor
        if modifiers.contains(.control) {
            // Marker cursor: wider and semi-transparent
            let diameter = max(16, min(currentLineWidth * 2, 48))
            let size = NSSize(width: diameter + 4, height: diameter + 4)
            let image = NSImage(size: size)
            image.lockFocus()
            currentColor.withAlphaComponent(0.3).setFill()
            let circleRect = NSRect(
                x: 2,
                y: 2,
                width: diameter,
                height: diameter
            )
            NSBezierPath(ovalIn: circleRect).fill()
            image.unlockFocus()
            let hotSpot = NSPoint(x: size.width / 2, y: size.height / 2)
            cursor = NSCursor(image: image, hotSpot: hotSpot)
        } else if modifiers.contains(.option) {
            if modifiers.contains(.shift) {
                cursor = ellipseCursor(centered: true)
            } else {
                cursor = ellipseCursor(centered: false)
            }
        } else if modifiers.contains(.command) {
            if modifiers.contains(.shift) {
                cursor = arrowCursor()
            } else {
                cursor = rectangleCursor()
            }
        } else if modifiers.contains(.shift) {
            cursor = freeHandCursor(isStraight: true)
        } else {
            cursor = freeHandCursor(isStraight: false)
        }
        penCursor = cursor
        self.discardCursorRects()
        self.window?.invalidateCursorRects(for: self)
        penCursor?.set()
    }

    func freeHandCursor(isStraight: Bool) -> NSCursor {
        let diameter = max(8, min(currentLineWidth, 48))
        let size = NSSize(width: diameter + 4, height: diameter + 4)
        let image = NSImage(size: size)
        image.lockFocus()
        currentColor.setFill()
        let circleRect = NSRect(x: 2, y: 2, width: diameter, height: diameter)
        NSBezierPath(ovalIn: circleRect).fill()

        if isStraight {
            let darkerColor =
                currentColor.usingColorSpace(.deviceRGB)?.shadow(withLevel: 0.5)
                ?? currentColor
            darkerColor.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 2, y: size.height / 2))
            path.line(to: NSPoint(x: size.width - 2, y: size.height / 2))
            path.lineWidth = 2
            path.stroke()
        }

        image.unlockFocus()

        let hotSpot = NSPoint(x: size.width / 2, y: size.height / 2)

        return NSCursor(image: image, hotSpot: hotSpot)
        //        self.discardCursorRects()
        //        self.window?.invalidateCursorRects(for: self)
    }

    func lineCursor() -> NSCursor {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()
        currentColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 6, y: 26))
        path.line(to: NSPoint(x: 26, y: 6))
        path.lineWidth = 3
        path.stroke()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 16, y: 16))
    }

    func arrowCursor() -> NSCursor {
        let size = NSSize(width: currentLineWidth, height: currentLineWidth)
        let image = NSImage(size: size)
        let symbolConfig = NSImage.SymbolConfiguration(paletteColors: [
            currentColor
        ])
        let symbolImage = NSImage(
            systemSymbolName: "arrow.up.right.circle",
            accessibilityDescription: nil
        )!
        .withSymbolConfiguration(symbolConfig)!
        image.lockFocus()
        symbolImage.draw(
            in: NSRect(
                x: 0,
                y: 0,
                width: currentLineWidth,
                height: currentLineWidth
            )
        )
        image.unlockFocus()
        return NSCursor(
            image: image,
            hotSpot: NSPoint(x: currentLineWidth / 2, y: currentLineWidth / 2)
        )
    }

    func rectangleCursor() -> NSCursor {
        let strokeWidth: CGFloat = 2
        let size = NSSize(width: currentLineWidth, height: currentLineWidth)
        let image = NSImage(size: size)
        image.lockFocus()
        currentColor.setStroke()
        // Inset by half the stroke width for equal line widths
        let rect = NSRect(
            x: strokeWidth / 2,
            y: strokeWidth / 2,
            width: currentLineWidth - strokeWidth,
            height: currentLineWidth - strokeWidth
        )
        let path = NSBezierPath(rect: rect)
        path.lineWidth = strokeWidth
        path.stroke()
        image.unlockFocus()
        return NSCursor(
            image: image,
            hotSpot: NSPoint(x: currentLineWidth / 2, y: currentLineWidth / 2)
        )
    }

    func ellipseCursor(centered: Bool) -> NSCursor {
        let diameter = max(8, min(currentLineWidth, 48))
        let size = NSSize(width: diameter + 4, height: diameter + 4)
        var image: NSImage
        if centered {
            let symbolConfig = NSImage.SymbolConfiguration(paletteColors: [
                currentColor
            ])
            let symbolImage = NSImage(
                systemSymbolName: "circle.circle",
                accessibilityDescription: nil
            )!
            .withSymbolConfiguration(symbolConfig)!
            image = NSImage(size: size)
            image.lockFocus()
            symbolImage.draw(
                in: NSRect(x: 2, y: 2, width: diameter, height: diameter)
            )
            image.unlockFocus()
        } else {
            let symbolConfig = NSImage.SymbolConfiguration(paletteColors: [
                currentColor
            ])
            let symbolImage = NSImage(
                systemSymbolName: "circle",
                accessibilityDescription: nil
            )!
            .withSymbolConfiguration(symbolConfig)!
            image = NSImage(size: size)
            image.lockFocus()
            symbolImage.draw(
                in: NSRect(x: 2, y: 2, width: diameter, height: diameter)
            )
            image.unlockFocus()
        }
        return NSCursor(
            image: image,
            hotSpot: NSPoint(x: size.width / 2, y: size.height / 2)
        )
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitTextField()
            return true
        }
        return false
    }

    func resetToDefaultCursor() {
        NSCursor.arrow.set()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let tf = textField, let container = textContainer else { return }

        let text = tf.stringValue
        let font = NSFont.systemFont(ofSize: textFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)

        let borderWidth: CGFloat = 8
        let minWidth: CGFloat = 100
        let padding: CGFloat = 10
        let newWidth = max(minWidth, textSize.width + padding)

        // Update text field frame
        tf.frame = NSRect(
            x: borderWidth,
            y: borderWidth,
            width: newWidth,
            height: tf.frame.height
        )

        // Update container frame
        container.frame = NSRect(
            x: container.frame.origin.x,
            y: container.frame.origin.y,
            width: newWidth + (borderWidth * 2),
            height: container.frame.height
        )
    }

    func showTextField(at point: NSPoint) {
        let height = textFontSize * 1.5
        let borderWidth: CGFloat = 8
        let initialWidth: CGFloat = 100

        let tf = NSTextField(
            frame: NSRect(
                x: borderWidth,
                y: borderWidth,
                width: initialWidth,
                height: height
            )
        )
        tf.font = NSFont.systemFont(ofSize: textFontSize)
        tf.textColor = currentColor
        tf.backgroundColor = .clear
        tf.isBordered = false
        tf.isEditable = true
        tf.isSelectable = true
        tf.focusRingType = .none
        tf.stringValue = ""
        tf.delegate = self
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true

        // Container view with wider border
        let container = NSView(
            frame: NSRect(
                x: point.x,
                y: point.y,
                width: initialWidth + (borderWidth * 2),
                height: height + (borderWidth * 2)
            )
        )
        container.wantsLayer = true
        container.layer?.borderColor = NSColor.systemBlue.cgColor
        container.layer?.borderWidth = borderWidth

        container.addSubview(tf)

        addSubview(container)
        window?.makeFirstResponder(tf)
        textField = tf
        textContainer = container
        textFieldOrigin = point
    }

    func updateTextFieldFont() {
        guard let tf = textField, let container = textContainer else { return }
        tf.font = NSFont.systemFont(ofSize: textFontSize)
        tf.textColor = currentColor

        let height = textFontSize * 1.5
        let borderWidth: CGFloat = 8

        // Recalculate width based on current text
        let text = tf.stringValue
        let font = NSFont.systemFont(ofSize: textFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)
        let minWidth: CGFloat = 100
        let padding: CGFloat = 10
        let newWidth = max(minWidth, textSize.width + padding)

        // Update container frame
        var containerFrame = container.frame
        containerFrame.size.height = height + (borderWidth * 2)
        containerFrame.size.width = newWidth + (borderWidth * 2)
        container.frame = containerFrame

        // Update text field frame
        tf.frame = NSRect(
            x: borderWidth,
            y: borderWidth,
            width: newWidth,
            height: height
        )

        // Update border width
        container.layer?.borderWidth = borderWidth
    }

    func commitTextField() {
        guard let tf = textField, let container = textContainer,
            !tf.stringValue.isEmpty
        else {
            cancelTextField()
            return
        }

        let attrString = NSAttributedString(
            string: tf.stringValue,
            attributes: [
                .font: NSFont.systemFont(ofSize: textFontSize),
                .foregroundColor: currentColor,
            ]
        )

        let font = NSFont.systemFont(ofSize: textFontSize)

        // Convert the text field's frame from its container's coordinates
        // to the main drawing view's coordinates.
        let textFieldFrameInView = container.convert(tf.frame, to: self)

        // The text is vertically centered in the text field. To find the baseline for
        // drawing, we start at the text field's bottom edge (origin.y), add half the
        // text field's height to get to the center, and then adjust downwards by
        // half the font's height to find the baseline.
        let totalFontHeight = font.ascender + abs(font.descender)
        let y_baseline =
            textFieldFrameInView.origin.y
            + (textFieldFrameInView.height - totalFontHeight) / 2
            + abs(font.descender) - 2

        let textPosition = NSPoint(
            x: textFieldFrameInView.origin.x + 2,
            y: y_baseline
        )

        paths.append(
            (
                .text(attrString, textPosition), currentColor,
                textFontSize
            )
        )

        container.removeFromSuperview()
        textField = nil
        textContainer = nil
        isEditingText = false
        drawMode = .freehand
        window?.makeFirstResponder(self)

        needsDisplay = true
    }

    func cancelTextField() {
        textContainer?.removeFromSuperview()
        textField = nil
        textContainer = nil
        isEditingText = false
        drawMode = .freehand
    }

}
