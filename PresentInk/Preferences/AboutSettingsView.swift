import Cocoa

class AboutSettingsView: NSView {
    let appIcon = NSImageView()
    let spacer = NSView()
    let appName = NSTextField(labelWithString: "PresentInk")
    let versionLabel: NSTextField = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return NSTextField(labelWithString: "Version \(version) (\(build))")
    }()
    let copyrightLabel = NSTextField(labelWithString: "Copyright © 2025 Erwin van Hunen")
  
    let thanksLabel = NSTextField(labelWithString: "Thank you for supporting PresentInk!")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        // App icon
        appIcon.image = NSImage(named: "AppIcon")
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.wantsLayer = true

        spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        // App name label
        appName.font = NSFont.boldSystemFont(ofSize: 22)
        appName.alignment = .center
        appName.textColor = .white

        versionLabel.font = NSFont.systemFont(ofSize: 15)
        versionLabel.alignment = .center
        versionLabel.textColor = NSColor(white: 1, alpha: 0.7)

        copyrightLabel.font = NSFont.systemFont(ofSize: 13)
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = NSColor(white: 1, alpha: 0.6)

        thanksLabel.font = NSFont.systemFont(ofSize: 14)
        thanksLabel.alignment = .center
        thanksLabel.textColor = NSColor(white: 1, alpha: 0.7)

        let buyMeACoffeeButton = ClickImageButton(image: NSImage(named: "BuyMeACoffee")!, width: 200, height: 56, action: #selector(buyMeACoffeeClicked), target: self)
        // Main vertical stack
        let stack = NSStackView(views: [
            appIcon,
            spacer,
            appName,
            versionLabel,
            copyrightLabel,
            buyMeACoffeeButton,
            thanksLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    @objc private func buyMeACoffeeClicked() {
        if let url = URL(string: "https://buymeacoffee.com/erwinvanhunen") {
            NSWorkspace.shared.open(url)
        }
        self.window?.close()
    }

    required init?(coder: NSCoder) { fatalError() }
}
