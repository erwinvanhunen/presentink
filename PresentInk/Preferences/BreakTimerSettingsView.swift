import Cocoa

class BreakTimerSettingsView: NSView {
    
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
        labelWithString: NSLocalizedString("Break Timer", comment: "")
            .uppercased()
    )

    private let slider = NSSlider(
        value: 10,
        minValue: 1,
        maxValue: 60,
        target: nil,
        action: nil
    )
    private let timeLabel = NSTextField(
        labelWithString: NSLocalizedString("Break Length", comment: "")
            + ": 10 " + NSLocalizedString("Minutes", comment: "")
    )
    private let messageField = NSTextField(string: "It's Break Time!")
    private let messageLabel = NSTextField(
        labelWithString: NSLocalizedString("Break Message", comment: "")
    )

    private let colorLabel = NSTextField(
        labelWithString: NSLocalizedString("Colors", comment: "")
    )

    private let backgroundColorWell = NSColorWell()
    private let backgroundColorLabel = NSTextField(
        labelWithString: NSLocalizedString("Background", comment: "")
    )

    private let timerColorWell = NSColorWell()
    private let timerColorLabel = NSTextField(
        labelWithString: NSLocalizedString("Timer", comment: "")
    )

    private let messageColorWell = NSColorWell()
    private let messageColorLabel = NSTextField(
        labelWithString: NSLocalizedString("Message", comment: "")
    )

    private let backgroundColorReset = NSButton(
        title: NSLocalizedString("Reset", comment: ""),
        target: nil,
        action: nil
    )
    private let messageColorReset = NSButton(
        title: NSLocalizedString("Reset", comment: ""),
        target: nil,
        action: nil
    )
    private let timerColorReset = NSButton(
        title: NSLocalizedString("Reset", comment: ""),
        target: nil,
        action: nil
    )

    private let colorGrid = NSGridView()

    var selectedMinutes: Int {
        Int(slider.intValue)
    }
    var breakMessage: String {
        messageField.stringValue
    }

    var backgroundColor: NSColor {
        backgroundColorWell.color
    }

    var timerColor: NSColor {
        timerColorWell.color
    }

    var messageColor: NSColor {
        messageColorWell.color
    }

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
    }

    private func setupUI() {
        let savedMinutes = Settings.shared.breakMinutes
        let savedMessage = Settings.shared.breakMessage
        //        let savedColor = Settings.shared.breakBackgroundColor

        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        slider.intValue = Int32(savedMinutes)
        timeLabel.stringValue =
            NSLocalizedString("Break Length", comment: "")
            + ": \(savedMinutes) " + NSLocalizedString("Minutes", comment: "")
        messageField.stringValue = savedMessage

        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true

        timeLabel.font = NSFont.systemFont(ofSize: 12)
        messageLabel.font = NSFont.systemFont(ofSize: 12)
        messageField.font = NSFont.systemFont(ofSize: 13)
        messageField.lineBreakMode = .byWordWrapping
        messageField.preferredMaxLayoutWidth = 400
        messageField.maximumNumberOfLines = 1

        messageField.translatesAutoresizingMaskIntoConstraints = false
        //        messageField.heightAnchor.constraint(equalToConstant: 80).isActive =
        //            true
        // messageField.backgroundColor = NSColor(calibratedWhite: 0.97, alpha: 1.0)

        messageField.target = self
        messageField.action = #selector(messageFieldChanged)

        backgroundColorLabel.font = NSFont.systemFont(ofSize: 12)
        backgroundColorWell.color = Settings.shared.breakBackgroundColor
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorChanged)

        backgroundColorReset.target = self
        backgroundColorReset.action = #selector(resetBackgroundColor)

        timerColorLabel.font = NSFont.systemFont(ofSize: 12)
        timerColorWell.color = Settings.shared.breakTimerColor
        timerColorWell.target = self
        timerColorWell.action = #selector(timerColorChanged)

        timerColorReset.target = self
        timerColorReset.action = #selector(resetTimerColor)

        messageColorLabel.font = NSFont.systemFont(ofSize: 12)
        messageColorWell.color = Settings.shared.breakMessageColor
        messageColorWell.target = self
        messageColorWell.action = #selector(messageColorChanged)

        messageColorReset.target = self
        messageColorReset.action = #selector(resetMessageColor)

        colorGrid.addRow(with: [
            backgroundColorLabel, backgroundColorWell, backgroundColorReset,
        ])
        colorGrid.addRow(with: [
            timerColorLabel, timerColorWell, timerColorReset,
        ])
        colorGrid.addRow(with: [
            messageColorLabel, messageColorWell, messageColorReset,
        ])

        for row in 0..<colorGrid.numberOfRows {
            colorGrid.row(at: row).yPlacement = .center
        }

        colorGrid.translatesAutoresizingMaskIntoConstraints = false
        colorGrid.columnSpacing = 16
        colorGrid.rowSpacing = 8
        let stack = NSStackView(views: [
            titleLabel,
            timeLabel,
            slider,
            messageLabel,
            messageField,
            colorLabel,
            colorGrid,
        ])
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .left
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
            messageField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            colorGrid.widthAnchor.constraint(equalToConstant: 220),  // Add this line
        ])
    }

    @objc private func sliderChanged() {
        timeLabel.stringValue =
            NSLocalizedString("Break Length", comment: "")
            + ": \(selectedMinutes) "
            + NSLocalizedString("Minutes", comment: "")
        Settings.shared.breakMinutes = selectedMinutes
    }

    @objc private func messageFieldChanged() {
        Settings.shared.breakMessage = breakMessage
    }

    @objc private func backgroundColorChanged() {
        Settings.shared.breakBackgroundColor = backgroundColor
    }

    @objc private func timerColorChanged() {
        Settings.shared.breakTimerColor = timerColor
    }

    @objc private func messageColorChanged() {
        Settings.shared.breakMessageColor = messageColor
    }

    @objc private func resetBackgroundColor() {
        backgroundColorWell.color = .white
        Settings.shared.breakBackgroundColor = .white
    }

    @objc private func resetTimerColor() {
        timerColorWell.color = .red
        Settings.shared.breakTimerColor = .red
    }

    @objc private func resetMessageColor() {
        messageColorWell.color = .black
        Settings.shared.breakMessageColor = .black
    }
}
