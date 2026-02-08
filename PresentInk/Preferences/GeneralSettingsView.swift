//
//  GeneralSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-10.
//
import Cocoa

class GeneralSettingsView: NSView {

    let languageCodes = ["en", "nl", "sv"]
    let languageNames = ["English", "Nederlands", "Svenska"]

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
            labelWithString: NSLocalizedString("General", comment: "")
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

    let textTyperLabel: NSTextField = {
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
    let launchSwitch = NSSwitch()
    let launchLabel = NSTextField(
        labelWithString: NSLocalizedString("Launch at login", comment: "")
    )

    let experimentalLabel = NSTextField(
        labelWithString: NSLocalizedString(
            "Experimental features (Text Typer)",
            comment: ""
        )
    )
    let experimentalSwitch = NSSwitch()

    let languageLabel = NSTextField(
        labelWithString: NSLocalizedString("Language", comment: "")
    )
    let languagePopUp = NSPopUpButton()

    private let screenshotLocationLabel = NSTextField(
        labelWithString: NSLocalizedString("Default screenshot location", comment: "")
    )
    private let screenshotPathField: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.lineBreakMode = .byTruncatingMiddle
        tf.isSelectable = true
        return tf
    }()
    private let chooseScreenshotButton: NSButton = {
        let b = NSButton(title: NSLocalizedString("Choose…", comment: ""), target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    private let clearScreenshotButton: NSButton = {
        let b = NSButton(title: NSLocalizedString("Clear", comment: ""), target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    private let screenshotBehaviorLabel = NSTextField(
        labelWithString: NSLocalizedString(
            "When set, pressing Enter or clicking Save will write the screenshot to this folder without asking.",
            comment: ""
        )
    )
    private let screenshotButtons = NSStackView()
    private let screenshotRow = NSStackView()
    private var screenshotPathMinWidthConstraint: NSLayoutConstraint?

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
        
//        layer?.backgroundColor = NSColor.clear.cgColor

        languageLabel.font = NSFont.systemFont(ofSize: 12)
        languagePopUp.addItems(withTitles: languageNames)
        if let selectedIndex = languageCodes.firstIndex(
            of: Settings.shared.languageCode
        ) {
            languagePopUp.selectItem(at: selectedIndex)
        } else {
            languagePopUp.selectItem(at: 0)
        }
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged(_:))

        let languageRow = NSStackView(views: [languageLabel, languagePopUp])
        languageRow.orientation = .horizontal
        languageRow.alignment = .centerY
        languageRow.spacing = 16

        launchLabel.font = NSFont.systemFont(ofSize: 12)
        experimentalLabel.font = NSFont.systemFont(ofSize: 12)

        // Set initial state from settings
        launchSwitch.state = Settings.shared.launchAtLogin ? .on : .off
        launchSwitch.target = self
        launchSwitch.action = #selector(launchSwitchToggled(_:))

        let launchRow = NSStackView(views: [launchLabel, launchSwitch])
        launchRow.orientation = .horizontal
        launchRow.alignment = .centerY
        launchRow.spacing = 16

        experimentalSwitch.state =
            Settings.shared.showExperimentalFeatures ? .on : .off
        experimentalSwitch.target = self
        experimentalSwitch.action = #selector(experimentalSwitchToggled(_:))

        let experimentalRow = NSStackView(views: [
            experimentalLabel, experimentalSwitch,
        ])
        experimentalRow.orientation = .horizontal
        experimentalRow.alignment = .centerY
        experimentalRow.spacing = 16

        screenshotLocationLabel.font = NSFont.systemFont(ofSize: 12)
        screenshotLocationLabel.textColor = sectionLabel.textColor
        screenshotPathField.font = NSFont.systemFont(ofSize: 12)
        screenshotBehaviorLabel.font = NSFont.systemFont(ofSize: 11)
        screenshotBehaviorLabel.textColor = .secondaryLabelColor
        screenshotBehaviorLabel.maximumNumberOfLines = 0
        screenshotBehaviorLabel.lineBreakMode = .byWordWrapping

        chooseScreenshotButton.target = self
        chooseScreenshotButton.action = #selector(chooseScreenshotLocation(_:))
        clearScreenshotButton.target = self
        clearScreenshotButton.action = #selector(clearScreenshotLocation(_:))

        screenshotButtons.orientation = .horizontal
        screenshotButtons.spacing = 8
        screenshotButtons.alignment = .centerY
        screenshotButtons.addArrangedSubview(chooseScreenshotButton)
        screenshotButtons.addArrangedSubview(clearScreenshotButton)

        let screenshotControlsRow = NSStackView(views: [screenshotPathField, screenshotButtons])
        screenshotControlsRow.orientation = .horizontal
        screenshotControlsRow.alignment = .centerY
        screenshotControlsRow.spacing = 16

        screenshotRow.orientation = .vertical
        screenshotRow.alignment = .leading
        screenshotRow.distribution = .fill
        screenshotRow.spacing = 8
        screenshotRow.addArrangedSubview(screenshotLocationLabel)
        screenshotRow.addArrangedSubview(screenshotControlsRow)

        screenshotPathField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        screenshotPathMinWidthConstraint = screenshotPathField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        screenshotPathMinWidthConstraint?.priority = .defaultLow
        screenshotPathMinWidthConstraint?.isActive = true
        chooseScreenshotButton.setContentHuggingPriority(.required, for: .horizontal)
        clearScreenshotButton.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [
            sectionLabel, languageRow, launchRow, experimentalRow,
            screenshotRow, screenshotBehaviorLabel,
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
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -32
            ),
        ])

        if let path = Settings.shared.screenshotSaveUrl?.path {
            screenshotPathField.stringValue = path
        } else {
            screenshotPathField.stringValue = NSLocalizedString("(Ask on save)", comment: "")
        }
    }

    @objc func languageChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        let newLanguageCode = languageCodes[selectedIndex]
        // Only show dialog if language actually changed
        Settings.shared.languageCode = newLanguageCode
        // Show restart dialog
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Language Changed", comment: "")
        alert.informativeText = NSLocalizedString(
            "PresentInk needs to be restarted for the language change to take effect.",
            comment: ""
        )
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.alertStyle = .informational

        alert.runModal()

        NotificationCenter.default.post(
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )

    }

    @objc func launchSwitchToggled(_ sender: NSSwitch) {
        Settings.shared.launchAtLogin = (sender.state == .on)
    }

    @objc func experimentalSwitchToggled(_ sender: NSSwitch) {
        Settings.shared.showExperimentalFeatures = (sender.state == .on)
        NotificationCenter.default.post(
            name: NSNotification.Name("ExperimentalFeaturesToggled"),
            object: nil
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("HotkeyRecordingStopped"),
            object: nil
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("SetupPreferencesUI"),
            object: nil
        )  //
    }

    @objc private func chooseScreenshotLocation(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("Choose", comment: "")
        panel.message = NSLocalizedString("Select the default folder where screenshots will be saved.", comment: "")

        if let parentWindow = window {
            panel.beginSheetModal(for: parentWindow) { response in
                if response == .OK, let url = panel.url {
                    Settings.shared.screenshotSaveUrl = url
                    DispatchQueue.main.async {
                        self.screenshotPathField.stringValue = url.path
                    }
                }
            }
        } else {
            if panel.runModal() == .OK, let url = panel.url {
                Settings.shared.screenshotSaveUrl = url
                screenshotPathField.stringValue = url.path
            }
        }
    }

    @objc private func clearScreenshotLocation(_ sender: Any?) {
        Settings.shared.screenshotSaveUrl = nil
        screenshotPathField.stringValue = NSLocalizedString("(Use default)", comment: "")
    }

    @objc func typingSpeedChanged(_ sender: NSPopUpButton) {
        Settings.shared.typingSpeedIndex = sender.indexOfSelectedItem
    }

    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        updateScreenshotButtonsLayout()
        updateScreenshotBehaviorLayout()
    }

    private func updateScreenshotButtonsLayout() {
        let availableWidth = bounds.width - 64
        let labelWidth = screenshotLocationLabel.fittingSize.width
        let buttonsWidth = chooseScreenshotButton.intrinsicContentSize.width
            + clearScreenshotButton.intrinsicContentSize.width + 8
        let minPathWidth: CGFloat = 120
        let requiredWidth = labelWidth + 16 + minPathWidth + 16 + buttonsWidth

        if availableWidth < requiredWidth {
            screenshotButtons.orientation = .vertical
            screenshotButtons.alignment = .leading
        } else {
            screenshotButtons.orientation = .horizontal
            screenshotButtons.alignment = .centerY
        }
    }

    private func updateScreenshotBehaviorLayout() {
        let availableWidth = bounds.width - 64
        screenshotBehaviorLabel.preferredMaxLayoutWidth = max(200, availableWidth)
    }
}
