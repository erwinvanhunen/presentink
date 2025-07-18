import Cocoa

class HelpWindowController: NSWindowController {
    convenience init() {
        let size = NSSize(width: 640, height: 540)
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
        
        func shortcutRow(keys: [String], desc: String) -> NSStackView {
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
            
            let label = NSTextField(labelWithString: desc)
            label.font = NSFont.systemFont(ofSize: 15)
            label.textColor = NSColor.labelColor
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 2
            
            let hStack = NSStackView(views: [keyStack, label])
            hStack.orientation = .horizontal
            hStack.spacing = 12
            hStack.alignment = .centerY
            hStack.translatesAutoresizingMaskIntoConstraints = false
            return hStack
        }
        
        let shortcuts: [NSStackView] = [
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(keyCombo: Settings.shared.drawHotkey),
                desc: "Toggle draw mode on or off"
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(keyCombo: Settings.shared.screenShotHotkey),
                desc:
                    "Take a rectangular screenshot and copy it to the clipboard."
            ),
            shortcutRow(
                keys: HelpWindowController.getKeyModifiers(keyCombo: Settings.shared.breakTimerHotkey),
                desc: "Start a break timer"
            ),
    ]
    let drawShortCuts: [NSStackView] = [
            shortcutRow(keys: ["Esc"], desc: "Exit draw, screenshot or break timer mode"),
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
            shortcutRow(keys: ["T"], desc: "Add text while in draw mode"),
            shortcutRow(keys: ["Cmd", "Z"], desc: "Undo last drawing"),
            shortcutRow(
                keys: ["r"],
                desc: "Change color to red"
            ),
            shortcutRow(
                keys: ["g"],
                desc: "Change color to green"
            ),
            shortcutRow(
                keys: ["b"],
                desc: "Change color to blue"
            ),
            shortcutRow(
                keys: ["y"],
                desc: "Change color to yellow"
            ),
            shortcutRow(
                keys: ["o"],
                desc: "Change color to orange"
            ),
            shortcutRow(
                keys: ["p"],
                desc: "Change color to pink"
            ),
            shortcutRow(
                keys: ["w"],
                desc: "Activate whiteboard mode (draw on a white background)"
            ),
            shortcutRow(
                keys: ["k"],
                desc: "Activate blackboard mode (draw on a black background)"
                )
        ]
        
        //        let textDesc = NSTextField(labelWithString:
        //            "While in draw mode allows to add text.\nWhile typing use cursor up or down or the mouse wheel to change the text size. Move the text with the mouse to the desired location and press enter to place it."
        //        )
        //        textDesc.font = NSFont.systemFont(ofSize: 13)
        //        textDesc.textColor = NSColor.secondaryLabelColor
        //        textDesc.lineBreakMode = .byWordWrapping
        //        textDesc.maximumNumberOfLines = 3
        
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
    }
    
    private static func getKeyModifiers(keyCombo: SettingsKeyCombo) -> [String] {
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
