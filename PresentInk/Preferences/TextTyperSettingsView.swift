import Cocoa

class TextTyperSettingsView: NSView {
    var typingSpeedRow: NSStackView?
    
    private let backgroundView: NSVisualEffectView = {
           let v = NSVisualEffectView()
           v.material = .sidebar
           v.blendingMode = .withinWindow
           v.state = .active
           v.appearance = NSAppearance(named: .vibrantDark)
           v.translatesAutoresizingMaskIntoConstraints = false
           return v
       }()
    
    let sectionLabel: NSTextField = {
        let label = NSTextField(
            labelWithString: NSLocalizedString("Text Typer", comment: "")
                .uppercased()
        )
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }()

    let typingSpeedLabel = NSTextField(
        labelWithString: NSLocalizedString("Typing speed", comment: "")
    )
    let typingSpeedSelector: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: [
            NSLocalizedString("Slow", comment: ""),
            NSLocalizedString("Normal", comment: ""),
            NSLocalizedString("Fast", comment: ""),
        ])
        return popup
    }()

    // New UI elements
    let selectFileButton: NSButton = {
        let button = NSButton(
            title: "Select Text File",
            target: nil,
            action: nil
        )
        button.bezelStyle = .rounded
        return button
    }()
    let selectedFileLabel: NSTextField = {
        let label = NSTextField(labelWithString: "No file selected")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        return label
    }()
    
    let clearFileButton: NSButton = {
        let button = NSButton(
            title: "Clear",
            target: nil,
            action: nil
        )
        button.bezelStyle = .rounded
        return button
    }()

    let previewTextView: NSTextView = {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = NSColor.lightGray
        textView.backgroundColor = NSColor.darkGray
        textView.autoresizingMask = [.width]
        textView.layer?.borderColor = NSColor.gray.cgColor
        return textView
    }()
    let previewScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        return scrollView
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)

        // Background
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])


        typingSpeedLabel.font = NSFont.systemFont(ofSize: 12)

        typingSpeedSelector.selectItem(at: Settings.shared.typingSpeedIndex)
        typingSpeedSelector.target = self
        typingSpeedSelector.action = #selector(typingSpeedChanged(_:))

        typingSpeedRow = NSStackView(views: [
            typingSpeedLabel, typingSpeedSelector,
        ])
        typingSpeedRow?.orientation = .horizontal
        typingSpeedRow?.alignment = .centerY
        typingSpeedRow?.spacing = 16

        // File selection row
        let fileRow = NSStackView(views: [selectFileButton, clearFileButton, selectedFileLabel ])
        fileRow.orientation = .horizontal
        fileRow.alignment = .centerY
        fileRow.spacing = 16

        selectFileButton.target = self
        selectFileButton.action = #selector(selectFileButtonClicked)

        clearFileButton.target = self
        clearFileButton.action = #selector(clearFileButtonClicked)
        
        previewScrollView.documentView = previewTextView
        previewScrollView.heightAnchor.constraint(equalToConstant: 240)
            .isActive = true

        let stack = NSStackView(views: [
            sectionLabel, typingSpeedRow!, fileRow, previewScrollView,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 32
            ),
            stack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -32
            ),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -32
            ),
        ])

        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: Settings.shared.textTyperFile ?? Data(),
            options: .withSecurityScope,
            bookmarkDataIsStale: &isStale
        ) {
            guard url.startAccessingSecurityScopedResource() else { return }
            selectedFileLabel.stringValue =
                url.lastPathComponent
            previewTextView.string =
                (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }

    @objc func typingSpeedChanged(_ sender: NSPopUpButton) {
        Settings.shared.typingSpeedIndex = sender.indexOfSelectedItem
    }

    @objc func selectFileButtonClicked() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString(
            "Select a text file",
            comment: "Title for selecting text file"
        )
        if panel.runModal() == .OK, let url = panel.url {
            self.selectedFileLabel.stringValue = url.lastPathComponent
            let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            Settings.shared.textTyperFile = bookmarkData
            previewTextView.string =
                (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }
    
    @objc func clearFileButtonClicked() {
        Settings.shared.textTyperFile = nil
        selectedFileLabel.stringValue = "No file selected"
        previewTextView.string = ""
    }

    required init?(coder: NSCoder) { fatalError() }
}
