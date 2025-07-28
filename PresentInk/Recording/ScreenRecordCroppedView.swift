import Cocoa

class ScreenRecordCroppedView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var showIntroText: Bool = true
    private var screen: NSScreen
    private var isSelecting = false
    private var startPoint: NSPoint = NSPoint.zero
    private var currentRect: NSRect = NSRect.zero
    private var isDragging = false
    private var isResizing = false
    private var isMoving = false
    private var moveOffset: NSPoint = .zero
    private var resizeHandle: ResizeHandle = .none

    private let handleSize: CGFloat = 8.0

    private var startButton: NSButton!
    private var cancelButton: NSButton!
    private var introTextAlpha: CGFloat = 0.0
    enum ResizeHandle {
        case none, topLeft, topRight, bottomLeft, bottomRight, top, bottom,
            left, right, center, buttonBar
    }

    private lazy var buttonBar: NSView = {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor =
            NSColor(
                red: 0.0,
                green: 148 / 255,
                blue: 1,
                alpha: 1
            ).cgColor
        bar.layer?.cornerRadius = 18
        bar.translatesAutoresizingMaskIntoConstraints = false

        startButton = makeIconButton(
            symbolName: "record.circle.fill",
            action: #selector(startRecording),
            color: .white
        )
        cancelButton = makeIconButton(
            symbolName: "xmark.square.fill",
            action: #selector(cancelSelection)
        )

        let stack = NSStackView(views: [startButton, cancelButton])
        stack.orientation = .horizontal
        stack.spacing = 24
        stack.edgeInsets = NSEdgeInsets(
            top: 12,
            left: 18,
            bottom: 12,
            right: 18
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
        bar.isHidden = true
        return bar
    }()

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    init(frame: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frame)
        setupTrackingArea()
        _ = buttonBar
        addSubview(buttonBar)
        fadeInIntroText()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func resetCursorRects() {
        addCursorRect(buttonBar.frame, cursor: .arrow)
        // Moving hand cursor inside selection rectangle
        addCursorRect(currentRect, cursor: .openHand)
        super.resetCursorRects()
        if isSelecting || isResizing || isMoving {
            // Crosshair for the rest of the area
            addCursorRect(bounds, cursor: .crosshair)
            if !isSelecting {
                // Arrow cursor for button bar
                addCursorRect(buttonBar.frame, cursor: .arrow)
                // Moving hand cursor inside selection rectangle
                addCursorRect(currentRect, cursor: .openHand)
                for (corner, rect) in getResizeHandleRects() {
                    addCursorRect(rect, cursor: getCursorForHandle(corner))
                }
            }
        } else {
            addCursorRect(currentRect, cursor: .arrow)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    //    override func keyDown(with event: NSEvent) {
    //        if event.keyCode == 53 {  // Escape key
    //            cancelSelection()
    //        } else {
    //            super.keyDown(with: event)
    //        }
    //    }

    private func makeIconButton(
        symbolName: String,
        action: Selector,
        color: NSColor = NSColor.white
    ) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 6
        button.setButtonType(.momentaryPushIn)
        button.target = self
        button.action = action
        button.refusesFirstResponder = true

        let config = NSImage.SymbolConfiguration(
            pointSize: 18,
            weight: .regular
        )
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        button.imagePosition = .imageOnly
        button.contentTintColor = color
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40),
        ])

        return button
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            if event.keyCode == 53 {  // Escape key

                cancelSelection()

                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {

        case 53:  // Escape
            cancelSelection()
        default:
            super.keyDown(with: event)
        }
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func layout() {
        super.layout()
        positionButtonBar()
    }

    private func positionButtonBar() {
        guard !currentRect.isEmpty && !buttonBar.isHidden else { return }
        let barSize = buttonBar.fittingSize
        var barOrigin = NSPoint(
            x: currentRect.midX - barSize.width / 2,
            y: currentRect.minY - barSize.height - 12
        )
        if barOrigin.y < 8 {
            barOrigin.y = currentRect.maxY + 12
        }
        if barOrigin.y + barSize.height > bounds.height - 8 {
            barOrigin.y = bounds.height - barSize.height - 8
        }
        barOrigin.x = max(8, min(barOrigin.x, bounds.width - barSize.width - 8))
        buttonBar.frame = NSRect(origin: barOrigin, size: barSize)
        buttonBar.layoutSubtreeIfNeeded()
        if buttonBar.superview != nil {
            superview?.addSubview(
                buttonBar,
                positioned: .above,
                relativeTo: nil
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if buttonBar.isHidden && !currentRect.isEmpty {
            NSColor.systemBlue.setStroke()
            let borderPath = NSBezierPath(rect: currentRect)
            borderPath.lineWidth = 3.0
            borderPath.stroke()
        } else {
            NSColor.black.withAlphaComponent(0.3).setFill()
            dirtyRect.fill()
            if !currentRect.isEmpty {
                NSColor.clear.setFill()
                currentRect.fill(using: .copy)
                NSColor.systemBlue.setStroke()
                let borderPath = NSBezierPath(rect: currentRect)
                borderPath.lineWidth = 2.0
                borderPath.stroke()
                drawResizeHandles()
            }
        }
        positionButtonBar()
        if showIntroText {
            drawIntroText()
        }
    }

    private func drawIntroText() {
        let introText = """
            \(NSLocalizedString("Drag to select an area. Press Esc to cancel.",comment:""))
            """
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(introTextAlpha),
            .backgroundColor: NSColor.clear,
        ]
        let size = introText.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width + 40,
            height: size.height + 32
        )
        NSColor(
            red: 0.0,
            green: 148 / 255,
            blue: 1,
            alpha: introTextAlpha
        ).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 8, yRadius: 8).fill()
        let textOrigin = NSPoint(
            x: textRect.midX - size.width / 2,
            y: textRect.midY - size.height / 2
        )
        introText.draw(at: textOrigin, withAttributes: attributes)
    }
    
    private func fadeInIntroText() {
        showIntroText = true
        introTextAlpha = 0.0
        let duration: TimeInterval = 0.2
        let frameDuration: TimeInterval = 1 / 60.0
        let totalFrames = Int(duration / frameDuration)
        var currentFrame = 0

        Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)
            self.introTextAlpha = min(progress, 1.0)
            self.needsDisplay = true
            if currentFrame >= totalFrames {
                timer.invalidate()
                self.introTextAlpha = 1.0
                self.needsDisplay = true
            }
        }
    }

    private func fadeOutIntroText() {
        let duration: TimeInterval = 0.2
        let frameDuration: TimeInterval = 0.5 / 60.0
        let totalFrames = Int(duration / frameDuration)
        var currentFrame = 0

        Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) {
            [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)
            self.introTextAlpha = 1.0 - progress
            self.needsDisplay = true
            if currentFrame >= totalFrames {
                timer.invalidate()
                self.showIntroText = false
                self.introTextAlpha = 1.0
                self.needsDisplay = true
            }
        }
    }

    private func drawResizeHandles() {
        let handles = getResizeHandleRects()
        NSColor.systemBlue.setFill()
        for handle in handles.values { handle.fill() }
        NSColor.white.setStroke()
        for handle in handles.values {
            let path = NSBezierPath(rect: handle)
            path.lineWidth = 1.0
            path.stroke()
        }
    }

    private func getResizeHandleRects() -> [ResizeHandle: NSRect] {
        let halfHandle = handleSize / 2
        return [
            .topLeft: NSRect(
                x: currentRect.minX - halfHandle,
                y: currentRect.maxY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .topRight: NSRect(
                x: currentRect.maxX - halfHandle,
                y: currentRect.maxY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .bottomLeft: NSRect(
                x: currentRect.minX - halfHandle,
                y: currentRect.minY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .bottomRight: NSRect(
                x: currentRect.maxX - halfHandle,
                y: currentRect.minY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .top: NSRect(
                x: currentRect.midX - halfHandle,
                y: currentRect.maxY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .bottom: NSRect(
                x: currentRect.midX - halfHandle,
                y: currentRect.minY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .left: NSRect(
                x: currentRect.minX - halfHandle,
                y: currentRect.midY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
            .right: NSRect(
                x: currentRect.maxX - halfHandle,
                y: currentRect.midY - halfHandle,
                width: handleSize,
                height: handleSize
            ),
        ]
    }

    private func getResizeHandleAtPoint(_ point: NSPoint) -> ResizeHandle {
        let handles = getResizeHandleRects()
        for (handle, rect) in handles {
            if rect.contains(point) { return handle }
        }
        if currentRect.contains(point) {
            return .center
        }
        return .none
    }

    private func getCursorForHandle(_ handle: ResizeHandle) -> NSCursor {
        switch handle {
        case .topLeft:
            return NSCursor.frameResize(position: .topLeft, directions: .all)
        case .bottomRight:
            return NSCursor.frameResize(
                position: .bottomRight,
                directions: .all
            )
        case .topRight:
            return NSCursor.frameResize(position: .topRight, directions: .all)
        case .bottomLeft:
            return NSCursor.frameResize(position: .bottomLeft, directions: .all)
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .left, .right:
            return NSCursor.resizeLeftRight
        case .none, .buttonBar:
            return NSCursor.arrow
        case .center:
            return NSCursor.openHand
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let handle = getResizeHandleAtPoint(point)
        getCursorForHandle(handle).set()
    }

    override func mouseDown(with event: NSEvent) {
        if showIntroText {
            fadeOutIntroText()
        }
        let point = convert(event.locationInWindow, from: nil)
        if !currentRect.isEmpty {
        
            resizeHandle = getResizeHandleAtPoint(point)
            if resizeHandle != .none && resizeHandle != .buttonBar
                && resizeHandle != .center
            {
                isResizing = true
                return
            }
            // Check for move (inside rect, not on handle)
            if currentRect.contains(point) {

                isMoving = true
                moveOffset = NSPoint(
                    x: point.x - currentRect.origin.x,
                    y: point.y - currentRect.origin.y
                )
                return
            }
        }
        // Start new selection
        startPoint = point
        currentRect = NSRect(origin: point, size: NSSize.zero)
        isSelecting = true
        isDragging = true
        buttonBar.isHidden = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isResizing && resizeHandle != .none {
            resizeRectangle(to: point)
        } else if isMoving {
            // Move the rectangle, keeping the same size
            let newOrigin = NSPoint(
                x: point.x - moveOffset.x,
                y: point.y - moveOffset.y
            )
            // Clamp to bounds
            var clampedOrigin = newOrigin
            clampedOrigin.x = max(
                0,
                min(clampedOrigin.x, bounds.width - currentRect.width)
            )
            clampedOrigin.y = max(
                0,
                min(clampedOrigin.y, bounds.height - currentRect.height)
            )
            currentRect.origin = clampedOrigin
        } else if isDragging {
            currentRect = NSRect(
                x: min(startPoint.x, point.x),
                y: min(startPoint.y, point.y),
                width: abs(point.x - startPoint.x),
                height: abs(point.y - startPoint.y)
            )
        }
        needsDisplay = true
    }

    private func resizeRectangle(to point: NSPoint) {
        var newRect = currentRect
        switch resizeHandle {
        case .topLeft:
            newRect = NSRect(
                x: point.x,
                y: currentRect.minY,
                width: currentRect.maxX - point.x,
                height: point.y - currentRect.minY
            )
        case .topRight:
            newRect = NSRect(
                x: currentRect.minX,
                y: currentRect.minY,
                width: point.x - currentRect.minX,
                height: point.y - currentRect.minY
            )
        case .bottomLeft:
            newRect = NSRect(
                x: point.x,
                y: point.y,
                width: currentRect.maxX - point.x,
                height: currentRect.maxY - point.y
            )
        case .bottomRight:
            newRect = NSRect(
                x: currentRect.minX,
                y: point.y,
                width: point.x - currentRect.minX,
                height: currentRect.maxY - point.y
            )
        case .top:
            newRect = NSRect(
                x: currentRect.minX,
                y: currentRect.minY,
                width: currentRect.width,
                height: point.y - currentRect.minY
            )
        case .bottom:
            newRect = NSRect(
                x: currentRect.minX,
                y: point.y,
                width: currentRect.width,
                height: currentRect.maxY - point.y
            )
        case .left:
            newRect = NSRect(
                x: point.x,
                y: currentRect.minY,
                width: currentRect.maxX - point.x,
                height: currentRect.height
            )
        case .right:
            newRect = NSRect(
                x: currentRect.minX,
                y: currentRect.minY,
                width: point.x - currentRect.minX,
                height: currentRect.height
            )
        case .none, .buttonBar, .center:
            break
        }
        if newRect.width >= 10 && newRect.height >= 10 {
            currentRect = newRect
        }
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        isResizing = false
        isMoving = false
        resizeHandle = .none
        if currentRect.width > 10 && currentRect.height > 10 {
            buttonBar.isHidden = false
            positionButtonBar()
        }
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if !buttonBar.isHidden && buttonBar.frame.contains(point) {
            return buttonBar.hitTest(buttonBar.convert(point, from: self))
        }
        return super.hitTest(point)
    }

    @objc private func startRecording() {
        guard !currentRect.isEmpty else { return }
        let scale = screen.backingScaleFactor
        let screenRect = NSRect(
            x: currentRect.minX,
            y: bounds.height - currentRect.maxY,
            width: currentRect.width,
            height: currentRect.height
        )
        let cropRect = CGRect(
            x: screenRect.minX * scale,
            y: screenRect.minY * scale,
            width: screenRect.width * scale,
            height: screenRect.height * scale
        )
        buttonBar.isHidden = true
        needsDisplay = true
        onSelectionComplete?(cropRect)
    }

    @objc private func cancelSelection() {
        onCancel?()
        window?.close()
    }

    func switchToRecordingMode() {
        needsDisplay = true
    }
}
