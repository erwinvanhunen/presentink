//
//  RecordingSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-08-21.
//


// swift
import Cocoa

class RecordingSettingsView: NSView {

    // Dark background like other settings views
    private let backgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .withinWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel = NSTextField(
        labelWithString: NSLocalizedString("Recording", comment: "").uppercased()
    )

    private let recordAudioLabel = NSTextField(
        labelWithString: NSLocalizedString("Record Audio", comment: "")
    )
    private let recordAudioSwitch = NSSwitch()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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

        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
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

        setupUI()
        loadSettings()
    }

    private func setupUI() {
        // Title
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        // Record audio row
        recordAudioLabel.font = NSFont.systemFont(ofSize: 12)
        recordAudioLabel.textColor = .labelColor
        recordAudioLabel.isBezeled = false
        recordAudioLabel.drawsBackground = false
        recordAudioLabel.isEditable = false
        recordAudioLabel.isSelectable = false

        recordAudioSwitch.target = self
        recordAudioSwitch.action = #selector(recordAudioSwitchChanged)

        let audioRow = NSStackView(views: [recordAudioLabel, recordAudioSwitch])
        audioRow.orientation = .horizontal
        audioRow.spacing = 8
        audioRow.alignment = .centerY

        // Main stack
        let mainStack = NSStackView(views: [
            titleLabel,
            audioRow
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -32)
        ])
    }

    private func loadSettings() {
        recordAudioSwitch.state = Settings.shared.recordAudio ? .on : .off
    }

    @objc private func recordAudioSwitchChanged() {
        Settings.shared.recordAudio = (recordAudioSwitch.state == .on)
    }
}
