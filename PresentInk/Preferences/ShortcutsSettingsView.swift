//
//  ShortcutsSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-12.
//
import Carbon
import Cocoa
import HotKey

class ShortcutsSettingsView: NSView {

    // Persistent dark background
    private let backgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .withinWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Keep a handle to the content so we can rebuild it without removing the background
    private var mainStack: NSStackView?

    private let titleLabel = NSTextField(labelWithString: NSLocalizedString("Shortcuts", comment:"").uppercased())
    private let subtitleLabel = NSTextField(
        labelWithString: NSLocalizedString("Customize keyboard shortcuts for quick access. Click to change", comment: "")
    )

    private let drawLabel = NSTextField(labelWithString: NSLocalizedString("Draw", comment: ""))
    private let drawHotkeyField = HotkeyRecorderField()

    private let screenshotLabel = NSTextField(labelWithString: NSLocalizedString("Screenshot", comment: ""))
    private let screenshotHotkeyField = HotkeyRecorderField()

    private let breakTimerLabel = NSTextField(labelWithString: NSLocalizedString("Break Timer", comment: ""))
    private let breakTimerHotkeyField = HotkeyRecorderField()

    private let typeTextLabel = NSTextField(labelWithString: NSLocalizedString("Text Typer", comment: ""))
    private let typeTextHotkeyField = HotkeyRecorderField()

    private let screenRecordingLabel = NSTextField(labelWithString: NSLocalizedString("Record Screen", comment: ""))
    private let screenRecordingHotkeyField = HotkeyRecorderField()

    private let screenRecordingCroppedLabel = NSTextField(labelWithString: NSLocalizedString("Record cropped", comment:""))
    private let screenRecordingCroppedHotkeyField = HotkeyRecorderField()

    private let spotlightHotKeyField = HotkeyRecorderField()
    private let spotlightLabel = NSTextField(labelWithString: NSLocalizedString("Spotlight", comment: ""))

    private let magnifierHotKeyField = HotkeyRecorderField()
    private let magnifierLabel = NSTextField(labelWithString: NSLocalizedString("Magnifier", comment: ""))

    private let liveCaptionsHotkeyField = HotkeyRecorderField()
    private let liveCaptionsLabel = NSTextField(labelWithString: NSLocalizedString("Live captions", comment: ""))

    private var resetButtons: [HotkeyType: NSButton] = [:]

    private enum HotkeyType {
        case draw, screenshot, breakTimer, typeText, screenRecording, screenRecordingCropped, spotlight, magnifier, liveCaptions
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)

        // Background (added once, stays in the view)
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(experimentalFeaturesToggled),
            name: NSNotification.Name("ExperimentalFeaturesToggled"),
            object: nil
        )

        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func experimentalFeaturesToggled() {
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        // Rebuild only the content, not the background
        mainStack?.removeFromSuperview()
        resetButtons = [:]

        // Title and subtitle
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor

        // Labels styling
        [
            drawLabel, screenshotLabel, breakTimerLabel, screenRecordingLabel,
            screenRecordingCroppedLabel, spotlightLabel, typeTextLabel,
            magnifierLabel, liveCaptionsLabel
        ].forEach { label in
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .labelColor
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.widthAnchor.constraint(equalToConstant: 120).isActive = true
        }

        // Hotkey fields sizing (include cropped field)
        [
            drawHotkeyField, screenshotHotkeyField, breakTimerHotkeyField,
            typeTextHotkeyField, screenRecordingHotkeyField,
            screenRecordingCroppedHotkeyField, spotlightHotKeyField,
            magnifierHotKeyField, liveCaptionsHotkeyField
        ].forEach { field in
            field.heightAnchor.constraint(equalToConstant: 28).isActive = true
            field.widthAnchor.constraint(equalToConstant: 180).isActive = true
        }

        // Handlers with conflict checking
        drawHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .draw) {
                self.showConflictAlert()
                self.drawHotkeyField.keyCombo = Settings.shared.drawHotkey
            } else {
                Settings.shared.drawHotkey = combo
                self.updateResetButtons()
            }
        }
        screenshotHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .screenshot) {
                self.showConflictAlert()
                self.screenshotHotkeyField.keyCombo = Settings.shared.screenShotHotkey
            } else {
                Settings.shared.screenShotHotkey = combo
                self.updateResetButtons()
            }
        }
        breakTimerHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .breakTimer) {
                self.showConflictAlert()
                self.breakTimerHotkeyField.keyCombo = Settings.shared.breakTimerHotkey
            } else {
                Settings.shared.breakTimerHotkey = combo
                self.updateResetButtons()
            }
        }
        typeTextHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .typeText) {
                self.showConflictAlert()
                self.typeTextHotkeyField.keyCombo = Settings.shared.textTypeHotkey
            } else {
                Settings.shared.textTypeHotkey = combo
                self.updateResetButtons()
            }
        }
        screenRecordingHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .screenRecording) {
                self.showConflictAlert()
                self.screenRecordingHotkeyField.keyCombo = Settings.shared.screenRecordingHotkey
            } else {
                Settings.shared.screenRecordingHotkey = combo
                self.updateResetButtons()
            }
        }
        screenRecordingCroppedHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .screenRecordingCropped) {
                self.showConflictAlert()
                self.screenRecordingCroppedHotkeyField.keyCombo = Settings.shared.screenRecordingCroppedHotkey
            } else {
                Settings.shared.screenRecordingCroppedHotkey = combo
                self.updateResetButtons()
            }
        }
        spotlightHotKeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .spotlight) {
                self.showConflictAlert()
                self.spotlightHotKeyField.keyCombo = Settings.shared.spotlightHotkey
            } else {
                Settings.shared.spotlightHotkey = combo
                self.updateResetButtons()
            }
        }
        magnifierHotKeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .magnifier) {
                self.showConflictAlert()
                self.magnifierHotKeyField.keyCombo = Settings.shared.magnifierHotkey
            } else {
                Settings.shared.magnifierHotkey = combo
                self.updateResetButtons()
            }
        }
        liveCaptionsHotkeyField.onHotkeyChanged = { combo in
            if self.isHotkeyConflict(combo, excluding: .liveCaptions) {
                self.showConflictAlert()
                self.liveCaptionsHotkeyField.keyCombo = Settings.shared.liveCaptionsHotkey
            } else {
                Settings.shared.liveCaptionsHotkey = combo
                self.updateResetButtons()
            }
        }

        // Reset buttons
        let drawReset = ResetButton(action: #selector(resetDrawHotkey), target: self)
        let screenshotReset = ResetButton(action: #selector(resetScreenshotHotkey), target: self)
        let breakTimerReset = ResetButton(action: #selector(resetBreakTimerHotkey), target: self)
        let screenRecordingReset = ResetButton(action: #selector(resetScreenRecordingHotkey), target: self)
        let screenRecordingRectangleReset = ResetButton(action: #selector(resetScreenRecordingRectangleHotkey), target: self)
        let spotlightReset = ResetButton(action: #selector(resetSpotlightHotkey), target: self)
        let typeTextReset = ResetButton(action: #selector(resetTypeTextHotkey), target: self)
        let magnifierReset = ResetButton(action: #selector(resetMagnifierHotkey), target: self)
        let liveCaptionsReset = ResetButton(action: #selector(resetLiveCaptionsHotkey), target: self)

        resetButtons = [
            .draw: drawReset,
            .screenshot: screenshotReset,
            .breakTimer: breakTimerReset,
            .screenRecording: screenRecordingReset,
            .screenRecordingCropped: screenRecordingRectangleReset,
            .spotlight: spotlightReset,
            .typeText: typeTextReset,
            .magnifier: magnifierReset,
            .liveCaptions: liveCaptionsReset
        ]

        // Rows
        let drawStack = row(drawLabel, drawHotkeyField, drawReset)
        let screenshotStack = row(screenshotLabel, screenshotHotkeyField, screenshotReset)
        let breakTimerStack = row(breakTimerLabel, breakTimerHotkeyField, breakTimerReset)
        let screenRecordingStack = row(screenRecordingLabel, screenRecordingHotkeyField, screenRecordingReset)
        let screenRecordingRectangleStack = row(screenRecordingCroppedLabel, screenRecordingCroppedHotkeyField, screenRecordingRectangleReset)
        let spotlightStack = row(spotlightLabel, spotlightHotKeyField, spotlightReset)
        let magnifierStack = row(magnifierLabel, magnifierHotKeyField, magnifierReset)
        let liveCaptionsStack = row(liveCaptionsLabel, liveCaptionsHotkeyField, liveCaptionsReset)
        let typeTextStack = row(typeTextLabel, typeTextHotkeyField, typeTextReset)
        typeTextStack.isHidden = !Settings.shared.showExperimentalFeatures

        // Main stack
        let content = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            NSView(), // spacer
            drawStack,
            screenshotStack,
            breakTimerStack,
            screenRecordingStack,
            screenRecordingRectangleStack,
            spotlightStack,
            magnifierStack,
            liveCaptionsStack,
            typeTextStack
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false

        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])

        mainStack = content
    }

    private func row(_ label: NSTextField, _ field: NSView, _ reset: NSButton) -> NSStackView {
        let stack = NSStackView(views: [label, field, reset])
        stack.orientation = .horizontal
        stack.spacing = 16
        stack.alignment = .centerY
        return stack
    }

    @objc private func resetDrawHotkey() {
        Settings.shared.drawHotkey = SettingsKeyCombo(key: .d, modifiers: [.option, .shift])
        drawHotkeyField.keyCombo = Settings.shared.drawHotkey
        updateResetButtons()
    }
    @objc private func resetScreenshotHotkey() {
        Settings.shared.screenShotHotkey = SettingsKeyCombo(key: .s, modifiers: [.option, .shift])
        screenshotHotkeyField.keyCombo = Settings.shared.screenShotHotkey
        updateResetButtons()
    }
    @objc private func resetBreakTimerHotkey() {
        Settings.shared.breakTimerHotkey = SettingsKeyCombo(key: .b, modifiers: [.option, .shift])
        breakTimerHotkeyField.keyCombo = Settings.shared.breakTimerHotkey
        updateResetButtons()
    }
    @objc private func resetTypeTextHotkey() {
        Settings.shared.textTypeHotkey = SettingsKeyCombo(key: .t, modifiers: [.option, .shift])
        typeTextHotkeyField.keyCombo = Settings.shared.textTypeHotkey
        updateResetButtons()
    }
    @objc private func resetScreenRecordingHotkey() {
        Settings.shared.screenRecordingHotkey = SettingsKeyCombo(key: .r, modifiers: [.option, .shift])
        screenRecordingHotkeyField.keyCombo = Settings.shared.screenRecordingHotkey
        updateResetButtons()
    }
    @objc private func resetScreenRecordingRectangleHotkey() {
        Settings.shared.screenRecordingCroppedHotkey = SettingsKeyCombo(key: .r, modifiers: [.control, .shift])
        screenRecordingCroppedHotkeyField.keyCombo = Settings.shared.screenRecordingCroppedHotkey
        updateResetButtons()
    }
    @objc private func resetSpotlightHotkey() {
        Settings.shared.spotlightHotkey = SettingsKeyCombo(key: .f, modifiers: [.option, .shift])
        spotlightHotKeyField.keyCombo = Settings.shared.spotlightHotkey
        updateResetButtons()
    }
    @objc private func resetMagnifierHotkey() {
        Settings.shared.magnifierHotkey = SettingsKeyCombo(key: .m, modifiers: [.option, .shift])
        magnifierHotKeyField.keyCombo = Settings.shared.magnifierHotkey
        updateResetButtons()
    }
    @objc private func resetLiveCaptionsHotkey() {
        Settings.shared.liveCaptionsHotkey = SettingsKeyCombo(key: .c, modifiers: [.option, .shift])
        liveCaptionsHotkeyField.keyCombo = Settings.shared.liveCaptionsHotkey
        updateResetButtons()
    }

    private func updateResetButtons() {
        resetButtons[.draw]?.isEnabled = Settings.shared.drawHotkey != SettingsKeyCombo(key: .d, modifiers: [.option, .shift])
        resetButtons[.screenshot]?.isEnabled = Settings.shared.screenShotHotkey != SettingsKeyCombo(key: .s, modifiers: [.option, .shift])
        resetButtons[.breakTimer]?.isEnabled = Settings.shared.breakTimerHotkey != SettingsKeyCombo(key: .b, modifiers: [.option, .shift])
        resetButtons[.typeText]?.isEnabled = Settings.shared.textTypeHotkey != SettingsKeyCombo(key: .t, modifiers: [.option, .shift])
        resetButtons[.screenRecording]?.isEnabled = Settings.shared.screenRecordingHotkey != SettingsKeyCombo(key: .r, modifiers: [.option, .shift])
        resetButtons[.screenRecordingCropped]?.isEnabled = Settings.shared.screenRecordingCroppedHotkey != SettingsKeyCombo(key: .r, modifiers: [.control, .shift])
        resetButtons[.spotlight]?.isEnabled = Settings.shared.spotlightHotkey != SettingsKeyCombo(key: .f, modifiers: [.option, .shift])
        resetButtons[.magnifier]?.isEnabled = Settings.shared.magnifierHotkey != SettingsKeyCombo(key: .m, modifiers: [.option, .shift])
        resetButtons[.liveCaptions]?.isEnabled = Settings.shared.liveCaptionsHotkey != SettingsKeyCombo(key: .c, modifiers: [.option, .shift])
    }

    private func loadSettings() {
        drawHotkeyField.keyCombo = Settings.shared.drawHotkey
        screenshotHotkeyField.keyCombo = Settings.shared.screenShotHotkey
        breakTimerHotkeyField.keyCombo = Settings.shared.breakTimerHotkey
        typeTextHotkeyField.keyCombo = Settings.shared.textTypeHotkey
        screenRecordingHotkeyField.keyCombo = Settings.shared.screenRecordingHotkey
        screenRecordingCroppedHotkeyField.keyCombo = Settings.shared.screenRecordingCroppedHotkey
        spotlightHotKeyField.keyCombo = Settings.shared.spotlightHotkey
        magnifierHotKeyField.keyCombo = Settings.shared.magnifierHotkey
        liveCaptionsHotkeyField.keyCombo = Settings.shared.liveCaptionsHotkey
        updateResetButtons()
    }

    private func isHotkeyConflict(_ combo: SettingsKeyCombo, excluding: HotkeyType) -> Bool {
        let existingHotkeys: [SettingsKeyCombo] = {
            switch excluding {
            case .draw:
                return [Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .screenshot:
                return [Settings.shared.drawHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .breakTimer:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .typeText:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .screenRecording:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .screenRecordingCropped:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .spotlight:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.magnifierHotkey, Settings.shared.liveCaptionsHotkey]
            case .magnifier:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.liveCaptionsHotkey]
            case .liveCaptions:
                return [Settings.shared.drawHotkey, Settings.shared.screenShotHotkey, Settings.shared.breakTimerHotkey, Settings.shared.textTypeHotkey, Settings.shared.screenRecordingHotkey, Settings.shared.screenRecordingCroppedHotkey, Settings.shared.spotlightHotkey, Settings.shared.magnifierHotkey]
            }
        }()
        return existingHotkeys.contains { existing in
            existing.keyRawValue == combo.keyRawValue && existing.modifiersRawValue == combo.modifiersRawValue
        }
    }

    private func showConflictAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Shortcut Conflict", comment: "Alert title when a shortcut conflict occurs")
        alert.informativeText = NSLocalizedString("This keyboard shortcut is already assigned to another action. Please choose a different combination", comment:"")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

class HotkeyRecorderField: NSView {
    
    private let backgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .withinWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
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
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)

        // Background (added once, stays in the view)
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
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
        textField.stringValue = NSLocalizedString("Click to record", comment: "")
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
        textField.stringValue = NSLocalizedString("Press keys", comment:"")
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
            textField.stringValue = NSLocalizedString("Click to record", comment: "")
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
