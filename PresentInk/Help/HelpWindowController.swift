import Cocoa

class HelpWindowController: NSWindowController {
        
    @objc private func buyMeACoffeeClicked() {
        if let url = URL(string: "https://buymeacoffee.com/erwinvanhunen") {
            NSWorkspace.shared.open(url)
        }
        self.window?.close()
    }
    
    
    convenience init() {
        let size = NSSize(width: 800, height: 540)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Help"
        window.center()
        window.isReleasedWhenClosed = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 18
        contentStack.edgeInsets = NSEdgeInsets(
            top: 24,
            left: 32,
            bottom: 24,
            right: 32
        )
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.alignment = .left

       
        
        let title = NSTextField(labelWithString: "What is PresentInk?")
        title.font = NSFont.boldSystemFont(ofSize: 18)
        title.textColor = NSColor.labelColor

        let desc = NSTextField(
            labelWithString:
                "PresentInk is a macOS menu bar tool for drawing over your screen during presentations or screen sharing.\nUse it to highlight, annotate, and focus attention live."
        )
        desc.font = NSFont.systemFont(ofSize: 14)
        desc.textColor = NSColor.secondaryLabelColor
        desc.lineBreakMode = .byWordWrapping
        desc.maximumNumberOfLines = 2

        let keyboardTitle = NSTextField(labelWithString: "Keyboard")
        keyboardTitle.font = NSFont.boldSystemFont(ofSize: 16)
        keyboardTitle.textColor = NSColor.labelColor

        func shortcutRow(keys: [String], desc: String, color: NSColor? = nil)
            -> NSStackView
        {
            let keyStack = NSStackView()
            keyStack.orientation = .horizontal
            keyStack.spacing = 6
            for (i, k) in keys.enumerated() {
                keyStack.addArrangedSubview(KbdView(text: k, fontSize: 10))
                if i < keys.count - 1 {
                    let plus = NSTextField(labelWithString: "+")
                    plus.font = NSFont.systemFont(ofSize: 16)
                    plus.textColor = NSColor.tertiaryLabelColor
                    keyStack.addArrangedSubview(plus)
                }
            }
            keyStack.translatesAutoresizingMaskIntoConstraints = false
            keyStack.setContentHuggingPriority(.required, for: .horizontal)
            keyStack.widthAnchor.constraint(equalToConstant: 180).isActive =
                true

            let labelStack = NSStackView()
            labelStack.orientation = .horizontal
            labelStack.spacing = 8

            if let color = color {
                let colorBox = NSView(
                    frame: NSRect(x: 0, y: 0, width: 18, height: 18)
                )
                colorBox.wantsLayer = true
                colorBox.layer?.backgroundColor = color.cgColor
                colorBox.layer?.cornerRadius = 4
                colorBox.translatesAutoresizingMaskIntoConstraints = false
                colorBox.widthAnchor.constraint(equalToConstant: 18).isActive =
                    true
                colorBox.heightAnchor.constraint(equalToConstant: 18).isActive =
                    true
                labelStack.addArrangedSubview(colorBox)
            }
            let label = NSTextField(labelWithString: desc)
            label.font = NSFont.systemFont(ofSize: 15)
            label.textColor = NSColor.labelColor
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 2
            labelStack.addArrangedSubview(label)

            let hStack = NSStackView(views: [keyStack, labelStack])
            hStack.orientation = .horizontal
            hStack.spacing = 12
            hStack.alignment = .centerY
            hStack.translatesAutoresizingMaskIntoConstraints = false
            return hStack
        }

        let shortcuts: [NSStackView] = [
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.drawHotkey
                ),
                desc: "Toggle draw mode on or off"
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.screenShotHotkey
                ),
                desc:
                    "Take a rectangular screenshot and copy it to the clipboard."
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.breakTimerHotkey
                ),
                desc: "Start a break timer"
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.screenRecordingHotkey
                ),
                desc: "Start a screen recording"
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.screenRecordingCroppedHotkey
                ),
                desc: "Start a screen recording of a selected area"
            ),
        ]
        let drawShortCuts: [NSStackView] = [
            shortcutRow(
                keys: ["Esc"],
                desc: "Exit draw, screenshot or break timer mode"
            ),
            shortcutRow(keys: ["Shift"], desc: "Draw perfectly straight lines"),
            shortcutRow(keys: ["Cmd", "Shift"], desc: "Draw arrows"),
            shortcutRow(keys: ["Cmd"], desc: "Draw boxes (rectangles)"),
            shortcutRow(keys: ["Option"], desc: "Draw an ellipse"),
            shortcutRow(
                keys: ["Option", "Shift"],
                desc: "Draw a centered ellipse"
            ),
            shortcutRow(
                keys: ["Control"],
                desc: "Draw with a marker/highlighter"
            ),
            shortcutRow(
                keys: ["E"],
                desc: "Clear all drawings but stay in draw mode"
            ),
            shortcutRow(keys: ["T"], desc: "Add text"),
            shortcutRow(keys: ["Cmd", "Z"], desc: "Undo last drawing"),
            shortcutRow(
                keys: ["r"],
                desc: "Change color to red",
                color: .red
            ),
            shortcutRow(
                keys: ["g"],
                desc: "Change color to green",
                color: .green
            ),
            shortcutRow(
                keys: ["b"],
                desc: "Change color to blue",
                color: .blue
            ),
            shortcutRow(
                keys: ["y"],
                desc: "Change color to yellow",
                color: .yellow
            ),
            shortcutRow(
                keys: ["o"],
                desc: "Change color to orange",
                color: .orange
            ),
            shortcutRow(
                keys: ["p"],
                desc: "Change color to pink",
                color: .magenta
            ),
            shortcutRow(
                keys: ["w"],
                desc: "Activate whiteboard mode (draw on a white background)"
            ),
            shortcutRow(
                keys: ["k"],
                desc: "Activate blackboard mode (draw on a black background)"
            ),
            shortcutRow(
                keys: ["Space"],
                desc: "Center the cursor on the current screen"
            ),
        ]
        contentStack.addArrangedSubview(title)
        contentStack.addArrangedSubview(desc)
        contentStack.addArrangedSubview(keyboardTitle)
        for s in shortcuts { contentStack.addArrangedSubview(s) }
        //        contentStack.addArrangedSubview(textDesc)

        let drawTitle = NSTextField(labelWithString: "Draw mode keys")
        drawTitle.font = NSFont.boldSystemFont(ofSize: 16)
        drawTitle.textColor = NSColor.labelColor

        contentStack.addArrangedSubview(drawTitle)
        for s in drawShortCuts { contentStack.addArrangedSubview(s) }

        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = contentStack

        window.contentView = scrollView

        self.init(window: window)
        
        // Add the button to the content stack
        let buyMeACoffeeButton = ClickImageButton(image: NSImage(named: "BuyMeACoffee")!, width: 200, height: 56, action: #selector(buyMeACoffeeClicked), target: self)
        contentStack.insertArrangedSubview(buyMeACoffeeButton, at: 2)
        
        DispatchQueue.main.async {
            if let documentView = scrollView.documentView {
                let topPoint = NSPoint(x: 0, y: documentView.bounds.height - scrollView.contentView.bounds.height)
                scrollView.contentView.scroll(to: topPoint)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }

    private static func getKeyModifiers(keyCombo: SettingsKeyCombo) -> [String]
    {
        var modifiers: [String] = []
        if keyCombo.modifiers.contains(.command) {
            modifiers.append("Cmd")
        }
        if keyCombo.modifiers.contains(.option) {
            modifiers.append("Option")
        }
        if keyCombo.modifiers.contains(.shift) {
            modifiers.append("Shift")
        }
        if keyCombo.modifiers.contains(.control) {
            modifiers.append("Ctrl")
        }
        if let key = keyCombo.key {
            modifiers.append(key.description.uppercased())
        }
        return modifiers
    }
}
