import Cocoa

class BreakTimerSettingsView: NSView {
    private let titleLabel = NSTextField(labelWithString: "BREAK TIMER")

    private let slider = NSSlider(value: 10, minValue: 1, maxValue: 60, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "Break Length: 10 min")
    private let messageField = NSTextField(string: "It's Break Time!")
    private let messageLabel = NSTextField(labelWithString: "Break Message:")

    var selectedMinutes: Int {
        Int(slider.intValue)
    }
    var breakMessage: String {
        messageField.stringValue
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        let savedMinutes = Settings.shared.breakMinutes
        let savedMessage = Settings.shared.breakMessage

        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        
        slider.intValue = Int32(savedMinutes)
        timeLabel.stringValue = "Break Length: \(savedMinutes) min"
        messageField.stringValue = savedMessage

        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true

        timeLabel.font = NSFont.systemFont(ofSize: 12)
        messageLabel.font = NSFont.systemFont(ofSize: 12)
        messageField.font = NSFont.systemFont(ofSize: 13)
        messageField.lineBreakMode = .byWordWrapping
        messageField.preferredMaxLayoutWidth = 400
        messageField.maximumNumberOfLines = 4

        messageField.translatesAutoresizingMaskIntoConstraints = false
        messageField.heightAnchor.constraint(equalToConstant: 80).isActive = true
        // messageField.backgroundColor = NSColor(calibratedWhite: 0.97, alpha: 1.0)

        messageField.target = self
        messageField.action = #selector(messageFieldChanged)

       let stack = NSStackView(views: [
        titleLabel,
            timeLabel,
            slider,
            messageLabel,
            messageField
        ])
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            messageField.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func sliderChanged() {
        timeLabel.stringValue = "Break Length: \(selectedMinutes) min"
        Settings.shared.breakMinutes = selectedMinutes
    }

    @objc private func messageFieldChanged() {
        Settings.shared.breakMessage = breakMessage
    }
}
