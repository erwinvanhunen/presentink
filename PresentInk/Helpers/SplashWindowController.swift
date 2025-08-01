import Cocoa
import HotKey

class SplashWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SplashWindowController: NSWindowController {

    convenience init() {
        let screenFrame =
            NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let window = SplashWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .mainMenu + 1
        window.center()
        window.alphaValue = 0  // For fade-in
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.init(window: window)

        // Blur effect
        let blurView = NSVisualEffectView(frame: screenFrame)
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.wantsLayer = true

        let colorOverlay = NSView(frame: blurView.bounds)
        colorOverlay.wantsLayer = true
        colorOverlay.layer?.backgroundColor = NSColor(calibratedRed: 74/255, green: 113/255, blue: 139/255, alpha: 0.3).cgColor
        colorOverlay.autoresizingMask = [.width, .height]
        blurView.addSubview(colorOverlay, positioned: .above, relativeTo: nil)
        window.contentView?.addSubview(blurView)

        // Icon
        let iconView = NSImageView()
        iconView.image = NSImage(named: "AppIcon")  // Use your icon asset name
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 128).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 128).isActive = true

        // Title
        let title = NSTextField(labelWithString: "PresentInk")
        title.textColor = NSColor(white: 1, alpha: 0.8)
        title.font = NSFont.systemFont(ofSize: 64, weight: .semibold)
        title.alignment = .left
        title.backgroundColor = .clear
        title.isBezeled = false
        title.isEditable = false
        title.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowBlurRadius = 6
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            return shadow
        }()

        // Get shortcut from settings
        let shortcut = SplashWindowController.formatShortcut(
            key: Settings.shared.drawHotkey.key,
            modifiers: Settings.shared.drawHotkey.modifiers
        )

        let hintStack = NSStackView()
        hintStack.orientation = .horizontal
        hintStack.alignment = .centerY
        hintStack.spacing = 4
        hintStack.translatesAutoresizingMaskIntoConstraints = false

        let hintPrefix = NSTextField(labelWithString: "Press ")
        hintPrefix.font = NSFont.systemFont(ofSize: 20)
        hintPrefix.textColor = NSColor(white: 1, alpha: 0.8)
        hintPrefix.backgroundColor = .clear
        hintPrefix.isBezeled = false
        hintPrefix.isEditable = false

        hintStack.addArrangedSubview(hintPrefix)
        for (i, part) in shortcut.enumerated() {
            hintStack.addArrangedSubview(KbdView(text: part))
            if i < shortcut.count - 1 {
                let plus = NSTextField(labelWithString: "+")
                plus.font = NSFont.systemFont(ofSize: 20)
                plus.textColor = NSColor(white: 1, alpha: 0.8)
                plus.backgroundColor = .clear
                plus.isBezeled = false
                plus.isEditable = false
                hintStack.addArrangedSubview(plus)
            }
        }
        hintStack.addArrangedSubview(
            NSTextField(labelWithString: " to toggle drawing")
        )

        let textStack = NSStackView(views: [title, hintStack])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 12
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView(views: [iconView, textStack])
        hStack.orientation = .horizontal
        hStack.alignment = .top
        hStack.spacing = 16
        hStack.translatesAutoresizingMaskIntoConstraints = false

        blurView.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            hStack.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
        ])
    }

    static func formatShortcut(key: Key?, modifiers: NSEvent.ModifierFlags)
        -> [String]
    {
        var parts: [String] = []
        // Sort modifiers for consistent ord
        let sortedModifiers = modifiers.intersection([
            .command, .option, .control, .shift,
        ])
        if sortedModifiers.contains(.command) { parts.append("⌘") }
        if sortedModifiers.contains(.option) { parts.append("Option") }
        if sortedModifiers.contains(.control) { parts.append("Ctrl") }
        if sortedModifiers.contains(.shift) { parts.append("Shift") }

        if let key = key {
            parts.append(key.description.uppercased())
        }
        return parts
    }

    func fadeIn(duration: TimeInterval) {
        guard let window = self.window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            window.animator().alphaValue = 1.0
        })
    }

    func fadeOutAndClose(after seconds: TimeInterval) {
        guard let window = self.window else { return }
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = seconds
                window.animator().alphaValue = 0
            },
            completionHandler: {
                window.orderOut(nil)
                self.close()
            }
        )
    }
}
