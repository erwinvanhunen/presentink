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

        let title = NSTextField(labelWithString: NSLocalizedString("What is PresentInk?", tableName: "Help", comment:""))
        title.font = NSFont.boldSystemFont(ofSize: 18)
        title.textColor = NSColor.labelColor

        let desc = NSTextField(
            labelWithString:
                NSLocalizedString("PresentInk is a macOS menu bar tool for drawing over your screen during presentations or screen sharing", tableName: "Help", comment:"")
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

        var shortcuts: [NSStackView] = [
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.drawHotkey
                ),
                desc: NSLocalizedString("Toggle draw mode on or off", tableName: "Help",comment:"")
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.screenShotHotkey
                ),
                desc:
                    NSLocalizedString("Take a rectangular screenshot and copy it to the clipboard.", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.breakTimerHotkey
                ),
                desc: NSLocalizedString("Start a break timer", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.screenRecordingHotkey
                ),
                desc: NSLocalizedString("Start a screen recording", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.screenRecordingCroppedHotkey
                ),
                desc: NSLocalizedString("Start a screen recording of a selected area", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.spotlightHotkey
                ),
                desc: NSLocalizedString("Start a spotlight", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(
                    keyCombo: Settings.shared.magnifierHotkey
                ),
                desc: NSLocalizedString("Start and stop the magnifier", tableName: "Help", comment:"")
            )
        ]
        if Settings.shared.showExperimentalFeatures {
            shortcuts.append(
                shortcutRow(
                    keys: HelpWindowController.getKeyModifiers(
                        keyCombo: Settings.shared.textTypeHotkey
                    ),
                    desc: NSLocalizedString("Start the text typer (experimental feature)", tableName: "Help", comment:"")
                )
            )
        }
        
        let drawShortCuts: [NSStackView] = [
            shortcutRow(
                keys: ["Esc"],
                desc: NSLocalizedString("Exit draw, screenshot or break timer mode", tableName: "Help", comment:"")
            ),
            shortcutRow(keys: ["Shift"], desc: NSLocalizedString("Draw perfectly straight lines", tableName: "Help", comment:"")),
            shortcutRow(keys: ["Cmd", "Shift"], desc: NSLocalizedString("Draw arrows", tableName: "Help", comment:"")),
            shortcutRow(keys: ["Cmd"], desc: NSLocalizedString("Draw boxes (rectangles)", tableName: "Help", comment:"")),
            shortcutRow(keys: ["Option"], desc: NSLocalizedString("Draw an ellipse", tableName: "Help", comment:"")),
            shortcutRow(
                keys: ["Option", "Shift"],
                desc: NSLocalizedString("Draw a centered ellipse", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: ["Control"],
                desc: NSLocalizedString("Draw with a marker/highlighter", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: ["E"],
                desc: NSLocalizedString("Clear all drawings but stay in draw mode", tableName: "Help", comment:"")
            ),
            shortcutRow(keys: ["T"], desc: NSLocalizedString("Add text", tableName: "Help", comment:"")),
            shortcutRow(keys: ["Cmd", "Z"], desc: NSLocalizedString("Undo last drawing", tableName: "Help", comment:"")),
            shortcutRow(
                keys: ["Cmd", "Shift", "Z"],
                desc: NSLocalizedString("Redo last drawing", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: ["r"],
                desc: NSLocalizedString("Change color to red", tableName: "Help", comment:""),
                color: .red
            ),
            shortcutRow(
                keys: ["g"],
                desc: NSLocalizedString("Change color to green", tableName: "Help", comment:""),
                color: .green
            ),
            shortcutRow(
                keys: ["b"],
                desc: NSLocalizedString("Change color to blue", tableName: "Help", comment:""),
                color: .blue
            ),
            shortcutRow(
                keys: ["y"],
                desc: NSLocalizedString("Change color to yellow", tableName: "Help", comment:""),
                color: .yellow
            ),
            shortcutRow(
                keys: ["o"],
                desc: NSLocalizedString("Change color to orange", tableName: "Help", comment:""),
                color: .orange
            ),
            shortcutRow(
                keys: ["p"],
                desc: NSLocalizedString("Change color to pink", tableName: "Help", comment:""),
                color: .magenta
            ),
            shortcutRow(
                keys: ["w"],
                desc: NSLocalizedString("Activate whiteboard mode (draw on a white background)", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: ["k"],
                desc: NSLocalizedString("Activate blackboard mode (draw on a black background)", tableName: "Help", comment:"")
            ),
            shortcutRow(
                keys: ["Space"],
                desc: NSLocalizedString("Center the cursor on the current screen", tableName: "Help", comment:"")
            ),
        ]
        contentStack.addArrangedSubview(title)
        contentStack.addArrangedSubview(desc)
        contentStack.addArrangedSubview(keyboardTitle)
        for s in shortcuts { contentStack.addArrangedSubview(s) }
        //        contentStack.addArrangedSubview(textDesc)

        let drawTitle = NSTextField(labelWithString: NSLocalizedString("Draw mode keys", tableName: "Help", comment:""))
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
        let buyMeACoffeeButton = ClickImageButton(
            image: NSImage(named: "BuyMeACoffee")!,
            width: 200,
            height: 56,
            action: #selector(buyMeACoffeeClicked),
            target: self
        )
        contentStack.insertArrangedSubview(buyMeACoffeeButton, at: 2)

        DispatchQueue.main.async {
            if let documentView = scrollView.documentView {
                let topPoint = NSPoint(
                    x: 0,
                    y: documentView.bounds.height
                        - scrollView.contentView.bounds.height
                )
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
