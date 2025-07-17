//
//  ShortcutsSettingsView.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-12.
//

import Carbon
import Cocoa
import HotKey

class ShortcutsSettingsView: NSView {
    private let titleLabel = NSTextField(labelWithString: "SHORTCUTS")
    private let subtitleLabel = NSTextField(
        labelWithString:
            "Customize keyboard shortcuts for quick access. Click to change."
    )

    private let drawLabel = NSTextField(labelWithString: "Draw:")
    private let drawHotkeyField = HotkeyRecorderField()

    private let screenshotLabel = NSTextField(labelWithString: "Screenshot:")
    private let screenshotHotkeyField = HotkeyRecorderField()

    private let breakTimerLabel = NSTextField(labelWithString: "Break Timer:")
    private let breakTimerHotkeyField = HotkeyRecorderField()

    private let typeTextLabel = NSTextField(labelWithString: "Type text:")
    private let typeTextHotkeyField = HotkeyRecorderField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(experimentalFeaturesToggled),
            name: NSNotification.Name("experimentalFeaturesToggled"),
            object: nil
        )
        setupUI()
        loadSettings()
    }

    @objc private func experimentalFeaturesToggled() {
        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Configure title
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        // Configure subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor

        // Configure labels
        [drawLabel, screenshotLabel, breakTimerLabel, typeTextLabel].forEach {
            label in
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .labelColor
            label.setContentHuggingPriority(.required, for: .horizontal)
        }

        // Configure hotkey fields
        [
            drawHotkeyField, screenshotHotkeyField, breakTimerHotkeyField,
            typeTextHotkeyField,
        ].forEach { field in
            field.heightAnchor.constraint(equalToConstant: 28).isActive = true
            field.widthAnchor.constraint(equalToConstant: 180).isActive = true
        }

        // Set up targets with conflict checking
        drawHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .draw) {
                self.showConflictAlert()
                self.drawHotkeyField.keyCombo = Settings.shared.drawHotkey  // Revert
            } else {
                Settings.shared.drawHotkey = combo
            }
        }

        screenshotHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .screenshot) {
                self.showConflictAlert()
                self.screenshotHotkeyField.keyCombo =
                    Settings.shared.screenShotHotkey  // Revert
            } else {
                Settings.shared.screenShotHotkey = combo
            }
        }

        breakTimerHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .breakTimer) {
                self.showConflictAlert()
                self.breakTimerHotkeyField.keyCombo =
                    Settings.shared.breakTimerHotkey  // Revert
            } else {
                Settings.shared.breakTimerHotkey = combo
            }
        }

        typeTextHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .typeText) {
                self.showConflictAlert()
                self.typeTextHotkeyField.keyCombo =
                    Settings.shared.textTypeHotkey  // Revert
            } else {
                Settings.shared.textTypeHotkey = combo
            }
        }

        // Create stack views for each shortcut row
        let drawStack = NSStackView(views: [drawLabel, drawHotkeyField])
        drawStack.orientation = .horizontal
        drawStack.spacing = 16
        drawStack.alignment = .centerY

        let screenshotStack = NSStackView(views: [
            screenshotLabel, screenshotHotkeyField,
        ])
        screenshotStack.orientation = .horizontal
        screenshotStack.spacing = 16
        screenshotStack.alignment = .centerY

        let breakTimerStack = NSStackView(views: [
            breakTimerLabel, breakTimerHotkeyField,
        ])
        breakTimerStack.orientation = .horizontal
        breakTimerStack.spacing = 16
        breakTimerStack.alignment = .centerY

        // Main vertical stack
        let mainStack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            NSView(),  // Spacer
            drawStack,
            screenshotStack,
            breakTimerStack,
        ])
        let typeTextStack = NSStackView(views: [
            typeTextLabel, typeTextHotkeyField,
        ])
        typeTextStack.orientation = .horizontal
        typeTextStack.spacing = 16
        typeTextStack.alignment = .centerY
        mainStack.addArrangedSubview(typeTextStack)

        typeTextStack.isHidden = !Settings.shared.showExperimentalFeatures
        
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 32
            ),
            mainStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 32
            ),
            mainStack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),

            // Make label columns align
            drawLabel.widthAnchor.constraint(equalToConstant: 100),
            screenshotLabel.widthAnchor.constraint(equalToConstant: 100),
            breakTimerLabel.widthAnchor.constraint(equalToConstant: 100),
            typeTextLabel.widthAnchor.constraint(equalToConstant: 100),
        ])

    }

    private func loadSettings() {
        drawHotkeyField.keyCombo = Settings.shared.drawHotkey
        screenshotHotkeyField.keyCombo = Settings.shared.screenShotHotkey
        breakTimerHotkeyField.keyCombo = Settings.shared.breakTimerHotkey
        typeTextHotkeyField.keyCombo = Settings.shared.textTypeHotkey
    }

    private enum HotkeyType {
        case draw, screenshot, breakTimer, typeText
    }

    private func isHotkeyConflict(
        _ combo: SettingsKeyCombo,
        excluding: HotkeyType
    ) -> Bool {
        let existingHotkeys: [SettingsKeyCombo] = {
            switch excluding {
            case .draw:
                return [
                    Settings.shared.screenShotHotkey,
                    Settings.shared.breakTimerHotkey,
                    Settings.shared.textTypeHotkey,
                ]
            case .screenshot:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.breakTimerHotkey,
                    Settings.shared.textTypeHotkey,
                ]
            case .breakTimer:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.screenShotHotkey,
                    Settings.shared.textTypeHotkey,
                ]
            case .typeText:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.screenShotHotkey,
                    Settings.shared.breakTimerHotkey,
                ]
            }
        }()

        return existingHotkeys.contains { existing in
            existing.keyRawValue == combo.keyRawValue
                && existing.modifiersRawValue == combo.modifiersRawValue
        }
    }

    private func showConflictAlert() {
        let alert = NSAlert()
        alert.messageText = "Shortcut Conflict"
        alert.informativeText =
            "This keyboard shortcut is already assigned to another action. Please choose a different combination."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

class HotkeyRecorderField: NSView {
    var keyCombo: SettingsKeyCombo? {
        didSet {
            updateDisplay()
        }
    }

    var onHotkeyChanged: ((SettingsKeyCombo) -> Void)?

    private let textField = NSTextField()
    private var isRecording = false
    private var eventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.controlColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.alignment = .center
        textField.stringValue = "Click to record"
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: 8
            ),
            textField.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -8
            ),
        ])

        let clickGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(startRecording)
        )
        addGestureRecognizer(clickGesture)
    }

    @objc private func startRecording() {
        guard !isRecording else { return }

        NotificationCenter.default.post(
            name: NSNotification.Name("HotkeyRecordingStarted"),
            object: nil
        )
        isRecording = true
        textField.stringValue = "Press keys..."
        layer?.borderColor = NSColor.controlAccentColor.cgColor

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .keyDown, .flagsChanged,
        ]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil  // Consume the event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let key = Key(carbonKeyCode: UInt32(event.keyCode))
            let modifiers = event.modifierFlags.intersection([
                .command, .option, .shift, .control,
            ])

            if let key = key, !modifiers.isEmpty {
                let combo = SettingsKeyCombo(key: key, modifiers: modifiers)
                keyCombo = combo
                onHotkeyChanged?(combo)
            }

            stopRecording()
            NotificationCenter.default.post(
                name: NSNotification.Name("HotkeyRecordingStopped"),
                object: nil
            )
        }
    }

    private func stopRecording() {
        isRecording = false
        layer?.borderColor = NSColor.controlColor.cgColor

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        updateDisplay()
    }

    private func updateDisplay() {
        guard let combo = keyCombo else {
            textField.stringValue = "Click to record"
            return
        }

        var modifierString = ""
        let modifiers = combo.modifiers

        if modifiers.contains(.control) { modifierString += "⌃" }
        if modifiers.contains(.option) { modifierString += "⌥" }
        if modifiers.contains(.shift) { modifierString += "⇧" }
        if modifiers.contains(.command) { modifierString += "⌘" }

        let keyString = combo.key?.description ?? "?"
        textField.stringValue = modifierString + keyString.uppercased()
    }
}
