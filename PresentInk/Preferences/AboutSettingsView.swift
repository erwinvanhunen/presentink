//
//  AboutView.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-10.
//

import Cocoa

class AboutSettingsView: NSView {
    let appIcon = NSImageView()
    let appName = NSTextField(labelWithString: "PresentInk")
    let versionLabel: NSTextField = {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "1.0"
        let label = NSTextField(labelWithString: "Version \(version)")
        return label
    }()
    let copyrightLabel = NSTextField(
        labelWithString: "Copyright © 2025 Erwin van Hunen"
    )
    let donateButton = NSButton()
    let buyMeACoffeeButton = NSButton()
    let thanksLabel = NSTextField(
        labelWithString: "Thank you for supporting PresentInk!"
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        appIcon.image = NSImage(named: "AppIcon")
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.wantsLayer = true
        appIcon.layer?.cornerRadius = 24
        appIcon.layer?.masksToBounds = true
        appIcon.setContentHuggingPriority(.required, for: .vertical)
        appIcon.setContentHuggingPriority(.required, for: .horizontal)
        appIcon.widthAnchor.constraint(equalToConstant: 200).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 200).isActive = true
        addSubview(appIcon)

        // App name label
        appName.font = NSFont.boldSystemFont(ofSize: 22)
        appName.alignment = .center
        appName.textColor = .white
        appName.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appName)

        // Spacer for whitespace
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true  // adjust as needed
        addSubview(spacer)

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
        donateButton.title = "Donate ❤️"
        donateButton.font = NSFont.boldSystemFont(ofSize: 17)
        donateButton.bezelStyle = .regularSquare
        donateButton.isBordered = false
        donateButton.wantsLayer = true
        donateButton.layer?.backgroundColor =
            NSColor(calibratedRed: 1, green: 0.45, blue: 0.18, alpha: 1).cgColor
        donateButton.layer?.cornerRadius = 16
        donateButton.contentTintColor = .white
        donateButton.layer?.shadowColor =
            NSColor(calibratedRed: 1, green: 0.7, blue: 0.3, alpha: 0.7).cgColor
        donateButton.layer?.shadowOpacity = 1
        donateButton.layer?.shadowRadius = 10
        donateButton.layer?.shadowOffset = CGSize(width: 0, height: 0)
        donateButton.setContentHuggingPriority(.required, for: .horizontal)
        donateButton.setContentHuggingPriority(.required, for: .vertical)
        donateButton.widthAnchor.constraint(equalToConstant: 160).isActive =
            true
        donateButton.heightAnchor.constraint(equalToConstant: 44).isActive =
            true
        donateButton.target = self
        donateButton.action = #selector(donateButtonClicked)

        // Buy Me A Coffee button
        buyMeACoffeeButton.image = NSImage(named: "BuyMeACoffee")
        buyMeACoffeeButton.isBordered = false
        buyMeACoffeeButton.bezelStyle = .regularSquare
        buyMeACoffeeButton.imagePosition = .imageOnly
        buyMeACoffeeButton.target = self
        buyMeACoffeeButton.action = #selector(buyMeACoffeeClicked)
        buyMeACoffeeButton.translatesAutoresizingMaskIntoConstraints = false
        buyMeACoffeeButton.setContentHuggingPriority(
            .required,
            for: .horizontal
        )
        buyMeACoffeeButton.setContentHuggingPriority(.required, for: .vertical)
        buyMeACoffeeButton.widthAnchor.constraint(equalToConstant: 213)
            .isActive = true
        buyMeACoffeeButton.heightAnchor.constraint(equalToConstant: 60)
            .isActive = true

        //        // Create horizontal stack for buttons
        //        let buttonStack = NSStackView(views: [buyMeACoffeeButton])
        //        buttonStack.orientation = .horizontal
        //        buttonStack.alignment = .centerY
        //        buttonStack.spacing = 16
        //        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Main stack
        let stack = NSStackView(views: [
            versionLabel,
            copyrightLabel,
            buyMeACoffeeButton,
            thanksLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            appIcon.centerXAnchor.constraint(equalTo: centerXAnchor),
            appIcon.topAnchor.constraint(equalTo: topAnchor, constant: 0),

            appName.centerXAnchor.constraint(equalTo: centerXAnchor),
            appName.topAnchor.constraint(
                equalTo: appIcon.bottomAnchor,
                constant: 4
            ),

            spacer.centerXAnchor.constraint(equalTo: centerXAnchor),
            spacer.topAnchor.constraint(equalTo: appName.bottomAnchor),
            spacer.heightAnchor.constraint(equalToConstant: 8),  // reduced from 24

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.topAnchor.constraint(equalTo: spacer.bottomAnchor),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: 32
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
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
