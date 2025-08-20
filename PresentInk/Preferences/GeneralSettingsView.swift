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

        let stack = NSStackView(views: [
            sectionLabel, languageRow, launchRow, experimentalRow,
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

    @objc func typingSpeedChanged(_ sender: NSPopUpButton) {
        Settings.shared.typingSpeedIndex = sender.indexOfSelectedItem
    }

    required init?(coder: NSCoder) { fatalError() }
}
