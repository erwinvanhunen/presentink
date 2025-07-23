import Cocoa

class AboutSettingsView: NSView {
    let appIcon = NSImageView()
    let spacer = NSView()
    let appName = NSTextField(labelWithString: "PresentInk")
    let versionLabel: NSTextField = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return NSTextField(labelWithString: "Version \(version)")
    }()
    let copyrightLabel = NSTextField(labelWithString: "Copyright © 2025 Erwin van Hunen")
    let donateButton = NSButton()
    let buyMeACoffeeButton = NSButton()
    let thanksLabel = NSTextField(labelWithString: "Thank you for supporting PresentInk!")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        // App icon
        appIcon.image = NSImage(named: "AppIcon")
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.wantsLayer = true
//        appIcon.layer?.cornerRadius = 24
//        appIcon.layer?.masksToBounds = true
//        appIcon.widthAnchor.constraint(equalToConstant: 200).isActive = true
//        appIcon.heightAnchor.constraint(equalToConstant: 200).isActive = true

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

        // Donate button
//        donateButton.title = "Donate ❤️"
//        donateButton.font = NSFont.boldSystemFont(ofSize: 17)
//        donateButton.bezelStyle = .regularSquare
//        donateButton.isBordered = false
//        donateButton.wantsLayer = true
//        donateButton.layer?.backgroundColor = NSColor(calibratedRed: 1, green: 0.45, blue: 0.18, alpha: 1).cgColor
//        donateButton.layer?.cornerRadius = 16
//        donateButton.contentTintColor = .white
//        donateButton.layer?.shadowColor = NSColor(calibratedRed: 1, green: 0.7, blue: 0.3, alpha: 0.7).cgColor
//        donateButton.layer?.shadowOpacity = 1
//        donateButton.layer?.shadowRadius = 10
//        donateButton.layer?.shadowOffset = CGSize(width: 0, height: 0)
//        donateButton.setContentHuggingPriority(.required, for: .horizontal)
//        donateButton.setContentHuggingPriority(.required, for: .vertical)
//        donateButton.widthAnchor.constraint(equalToConstant: 160).isActive = true
//        donateButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
//        donateButton.target = self
//        donateButton.action = #selector(donateButtonClicked)

        // Buy Me A Coffee button
        buyMeACoffeeButton.image = NSImage(named: "BuyMeACoffee")
        buyMeACoffeeButton.isBordered = false
        buyMeACoffeeButton.bezelStyle = .regularSquare
        buyMeACoffeeButton.imagePosition = .imageOnly
        buyMeACoffeeButton.target = self
        buyMeACoffeeButton.action = #selector(buyMeACoffeeClicked)
        buyMeACoffeeButton.translatesAutoresizingMaskIntoConstraints = false
        buyMeACoffeeButton.setContentHuggingPriority(.required, for: .horizontal)
        buyMeACoffeeButton.setContentHuggingPriority(.required, for: .vertical)
        buyMeACoffeeButton.widthAnchor.constraint(equalToConstant: 213).isActive = true
        buyMeACoffeeButton.heightAnchor.constraint(equalToConstant: 60).isActive = true

        // Cursor for buyMeACoffeeButton
        let trackingArea = NSTrackingArea(
            rect: buyMeACoffeeButton.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        buyMeACoffeeButton.addTrackingArea(trackingArea)

        // Button stack
//        let buttonStack = NSStackView(views: [donateButton, buyMeACoffeeButton])
//        buttonStack.orientation = .horizontal
//        buttonStack.alignment = .centerY
//        buttonStack.spacing = 16

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

    override func resetCursorRects() {
        super.resetCursorRects()
        let buttonRect = convert(buyMeACoffeeButton.bounds, from: buyMeACoffeeButton)
        addCursorRect(buttonRect, cursor: .pointingHand)
    }

    @objc private func donateButtonClicked() {
        if let url = URL(string: "https://github.com/sponsors/erwinvanhunen") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func buyMeACoffeeClicked() {
        if let url = URL(string: "https://buymeacoffee.com/erwinvanhunen") {
            NSWorkspace.shared.open(url)
        }
        self.window?.close()
    }

    required init?(coder: NSCoder) { fatalError() }
}
