import Cocoa

class KbdView: NSView {
    private let label: NSTextField

    convenience init(text: String) {
        self.init(text: text, fontSize: 20)
    }

    init(text: String, fontSize: CGFloat) {
        self.label = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
        translatesAutoresizingMaskIntoConstraints = false
        applyColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        layer?.backgroundColor = NSColor.controlBackgroundColor
            .withAlphaComponent(0.9)
            .cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        label.textColor = NSColor.labelColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
