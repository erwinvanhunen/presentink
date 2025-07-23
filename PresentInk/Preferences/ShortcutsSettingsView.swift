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

    private let screenRecordingLabel = NSTextField(
        labelWithString: "Screen Recording:"
    )
    private let screenRecordingHotkeyField = HotkeyRecorderField()
    private let screenRecordingRectangleLabel = NSTextField(
        labelWithString: "Screen Recording Selection:"
    )
    private let screenRecordingRectangleHotkeyField = HotkeyRecorderField()

    private var resetButtons: [HotkeyType: NSButton] = [:]

    private enum HotkeyType {
        case draw, screenshot, breakTimer, typeText, screenRecording,
            screenRecordingRectangle
    }

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
        subviews.forEach { $0.removeFromSuperview() }
        resetButtons = [:]  // Reset buttons
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
        [
            drawLabel, screenshotLabel, breakTimerLabel, screenRecordingLabel,
            screenRecordingRectangleLabel, typeTextLabel,
        ].forEach {
            label in
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .labelColor
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.widthAnchor.constraint(equalToConstant: 120).isActive = true
        }

        // Configure hotkey fields
        [
            drawHotkeyField, screenshotHotkeyField, breakTimerHotkeyField,
            typeTextHotkeyField, screenRecordingHotkeyField,
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
                self.updateResetButtons()
            }
        }

        screenshotHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .screenshot) {
                self.showConflictAlert()
                self.screenshotHotkeyField.keyCombo =
                    Settings.shared.screenShotHotkey  // Revert
            } else {
                Settings.shared.screenShotHotkey = combo
                self.updateResetButtons()
            }
        }

        breakTimerHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .breakTimer) {
                self.showConflictAlert()
                self.breakTimerHotkeyField.keyCombo =
                    Settings.shared.breakTimerHotkey  // Revert
            } else {
                Settings.shared.breakTimerHotkey = combo
                self.updateResetButtons()
            }
        }

        typeTextHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .typeText) {
                self.showConflictAlert()
                self.typeTextHotkeyField.keyCombo =
                    Settings.shared.textTypeHotkey  // Revert
            } else {
                Settings.shared.textTypeHotkey = combo
                self.updateResetButtons()
            }
        }

        screenRecordingHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .screenRecording) {
                self.showConflictAlert()
                self.screenRecordingHotkeyField.keyCombo =
                    Settings.shared.screenRecordingHotkey  // Revert
            } else {
                Settings.shared.screenRecordingHotkey = combo
                self.updateResetButtons()
            }
        }

        screenRecordingRectangleHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(
                combo,
                excluding: .screenRecordingRectangle
            ) {
                self.showConflictAlert()
                self.screenRecordingRectangleHotkeyField.keyCombo =
                    Settings.shared.screenRecordingRectangleHotkey  // Revert
            } else {
                Settings.shared.screenRecordingRectangleHotkey = combo
                self.updateResetButtons()
            }
        }

        let drawReset = ResetButton(
            action: #selector(resetDrawHotkey),
            target: self
        )
        let screenshotReset = ResetButton(
            action: #selector(resetScreenshotHotkey),
            target: self
        )
        let breakTimerReset = ResetButton(
            action: #selector(resetBreakTimerHotkey),
            target: self
        )
        let screenRecordingReset = ResetButton(
            action: #selector(resetScreenRecordingHotkey),
            target: self
        )
        let screenRecordingRectangleReset = ResetButton(
            action: #selector(resetScreenRecordingRectangleHotkey),
            target: self
        )

        let typeTextReset = ResetButton(
            action: #selector(resetTypeTextHotkey),
            target: self
        )

        resetButtons = [
            .draw: drawReset,
            .screenshot: screenshotReset,
            .breakTimer: breakTimerReset,
            .screenRecording: screenRecordingReset,
            .screenRecordingRectangle: screenRecordingRectangleReset,
        ]
        if Settings.shared.showExperimentalFeatures {
            resetButtons[.typeText] = typeTextReset
        }

        // Create stack views for each shortcut row
        let drawStack = NSStackView(views: [
            drawLabel, drawHotkeyField, drawReset,
        ])
        drawStack.orientation = .horizontal
        drawStack.spacing = 16
        drawStack.alignment = .centerY

        let screenshotStack = NSStackView(views: [
            screenshotLabel, screenshotHotkeyField, screenshotReset,
        ])
        screenshotStack.orientation = .horizontal
        screenshotStack.spacing = 16
        screenshotStack.alignment = .centerY

        let breakTimerStack = NSStackView(views: [
            breakTimerLabel, breakTimerHotkeyField, breakTimerReset,
        ])
        breakTimerStack.orientation = .horizontal
        breakTimerStack.spacing = 16
        breakTimerStack.alignment = .centerY

        let screenRecordingStack = NSStackView(views: [
            screenRecordingLabel, screenRecordingHotkeyField,
            screenRecordingReset,
        ])
        screenRecordingStack.orientation = .horizontal
        screenRecordingStack.spacing = 16
        screenRecordingStack.alignment = .centerY

        let screenRecordingRectangleStack = NSStackView(views: [
            screenRecordingRectangleLabel, screenRecordingRectangleHotkeyField,
            screenRecordingRectangleReset,
        ])
        screenRecordingRectangleStack.orientation = .horizontal
        screenRecordingRectangleStack.spacing = 16
        screenRecordingRectangleStack.alignment = .centerY

        // Main vertical stack
        let mainStack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            NSView(),  // Spacer
            drawStack,
            screenshotStack,
            breakTimerStack,
            screenRecordingStack,
            screenRecordingRectangleStack,
        ])
        let typeTextStack = NSStackView(views: [
            typeTextLabel, typeTextHotkeyField, typeTextReset,
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
        ])

    }

    @objc private func resetDrawHotkey() {
        Settings.shared.drawHotkey = SettingsKeyCombo(
            key: .d,
            modifiers: [.option, .shift]
        )
        drawHotkeyField.keyCombo = SettingsKeyCombo(
            key: .d,
            modifiers: [.option, .shift]
        )
        updateResetButtons()
    }
    @objc private func resetScreenshotHotkey() {
        Settings.shared.screenShotHotkey = SettingsKeyCombo(
            key: .s,
            modifiers: [.option, .shift]
        )
        screenshotHotkeyField.keyCombo = SettingsKeyCombo(
            key: .s,
            modifiers: [.option, .shift]
        )
        updateResetButtons()
    }
    @objc private func resetBreakTimerHotkey() {
        Settings.shared.breakTimerHotkey = SettingsKeyCombo(
            key: .b,
            modifiers: [.option, .shift]
        )
        breakTimerHotkeyField.keyCombo = SettingsKeyCombo(
            key: .b,
            modifiers: [.option, .shift]
        )
        updateResetButtons()
    }
    @objc private func resetTypeTextHotkey() {
        Settings.shared.textTypeHotkey = SettingsKeyCombo(
            key: .t,
            modifiers: [.option, .shift]
        )
        typeTextHotkeyField.keyCombo = SettingsKeyCombo(
            key: .t,
            modifiers: [.option, .shift]
        )
        updateResetButtons()
    }
    @objc private func resetScreenRecordingHotkey() {
        Settings.shared.screenRecordingHotkey = SettingsKeyCombo(
            key: .r,
            modifiers: [.option, .shift]
        )
        screenRecordingHotkeyField.keyCombo = SettingsKeyCombo(
            key: .r,
            modifiers: [.option, .shift]
        )
        updateResetButtons()
    }
    @objc private func resetScreenRecordingRectangleHotkey() {
        Settings.shared.screenRecordingRectangleHotkey = SettingsKeyCombo(
            key: .r,
            modifiers: [.control, .shift]
        )
        screenRecordingRectangleHotkeyField.keyCombo = SettingsKeyCombo(
            key: .r,
            modifiers: [.control, .shift]
        )
        updateResetButtons()
    }

    private func updateResetButtons() {
        resetButtons[.draw]?.isEnabled =
            Settings.shared.drawHotkey
            != SettingsKeyCombo(key: .d, modifiers: [.option, .shift])
        resetButtons[.screenshot]?.isEnabled =
            Settings.shared.screenShotHotkey
            != SettingsKeyCombo(key: .s, modifiers: [.option, .shift])
        resetButtons[.breakTimer]?.isEnabled =
            Settings.shared.breakTimerHotkey
            != SettingsKeyCombo(key: .b, modifiers: [.option, .shift])
        resetButtons[.typeText]?.isEnabled =
            Settings.shared.textTypeHotkey
            != SettingsKeyCombo(key: .t, modifiers: [.option, .shift])
        resetButtons[.screenRecording]?.isEnabled =
            Settings.shared.screenRecordingHotkey
            != SettingsKeyCombo(key: .r, modifiers: [.option, .shift])
        resetButtons[.screenRecordingRectangle]?.isEnabled =
            Settings.shared.screenRecordingRectangleHotkey
            != SettingsKeyCombo(key: .r, modifiers: [.control, .shift])
    }

    private func loadSettings() {
        drawHotkeyField.keyCombo = Settings.shared.drawHotkey
        screenshotHotkeyField.keyCombo = Settings.shared.screenShotHotkey
        breakTimerHotkeyField.keyCombo = Settings.shared.breakTimerHotkey
        typeTextHotkeyField.keyCombo = Settings.shared.textTypeHotkey
        screenRecordingHotkeyField.keyCombo =
            Settings.shared.screenRecordingHotkey
        screenRecordingRectangleHotkeyField.keyCombo =
            Settings.shared.screenRecordingRectangleHotkey
        updateResetButtons()
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
                    Settings.shared.screenRecordingHotkey,
                    Settings.shared.screenRecordingRectangleHotkey,
                ]
            case .screenshot:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.breakTimerHotkey,
                    Settings.shared.textTypeHotkey,
                    Settings.shared.screenRecordingHotkey,
                    Settings.shared.screenRecordingRectangleHotkey,
                ]
            case .breakTimer:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.screenShotHotkey,
                    Settings.shared.textTypeHotkey,
                    Settings.shared.screenRecordingHotkey,
                    Settings.shared.screenRecordingRectangleHotkey,
                ]
            case .typeText:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.screenShotHotkey,
                    Settings.shared.breakTimerHotkey,
                    Settings.shared.screenRecordingHotkey,
                    Settings.shared.screenRecordingRectangleHotkey,
                ]
            case .screenRecording:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.screenShotHotkey,
                    Settings.shared.breakTimerHotkey,
                    Settings.shared.textTypeHotkey,
                    Settings.shared.screenRecordingRectangleHotkey,
                ]
            case .screenRecordingRectangle:
                return [
                    Settings.shared.drawHotkey,
                    Settings.shared.screenShotHotkey,
                    Settings.shared.breakTimerHotkey,
                    Settings.shared.textTypeHotkey,
                    Settings.shared.screenRecordingHotkey,
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

class ResetButton: NSButton {
    init(action: Selector, target: Any?) {
        super.init(frame: .zero)
        self.title = "Reset"
        self.bezelStyle = .rounded
        self.setButtonType(.momentaryPushIn)
        self.target = target as AnyObject
        self.action = action
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalToConstant: 60).isActive = true
        self.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
