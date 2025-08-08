//
//  WelcomeWindowController.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-08-07.
//


import Cocoa

class WelcomeWindowController: NSWindowController {
    private var currentStep = 0
    private let totalSteps = 4
    
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let stepIndicator = NSTextField(labelWithString: "")
    private var backButton = NSButton(title: "Back", target: nil, action: nil)
    private var nextButton = NSButton(title: "Next", target: nil, action: nil)
    private var skipButton = NSButton(title: "Skip", target: nil, action: nil)
    
    convenience init() {
        let size = NSSize(width: 600, height: 400)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to PresentInk"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .modalPanel
        
        self.init(window: window)
        setupUI()
        showStep(0)
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = NSColor.secondaryLabelColor
        descriptionLabel.alignment = .center
        descriptionLabel.isEditable = false
        descriptionLabel.isBezeled = false
        descriptionLabel.drawsBackground = false
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 500
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        stepIndicator.font = NSFont.systemFont(ofSize: 12)
        stepIndicator.textColor = NSColor.tertiaryLabelColor
        stepIndicator.alignment = .center
        stepIndicator.isEditable = false
        stepIndicator.isBezeled = false
        stepIndicator.drawsBackground = false
        
        // Create new button instances with proper target/action setup
         backButton = NSButton(title: "Back", target: self, action: #selector(backClicked))
         nextButton = NSButton(title: "Next", target: self, action: #selector(nextClicked))
        skipButton = NSButton(title: "Skip", target: self, action: #selector(skipClicked))
        
        backButton.isEnabled = false
        nextButton.keyEquivalent = "\r"
        
        let buttonStack = NSStackView(views: [backButton, NSView(), skipButton, nextButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
     
        
        let mainStack = NSStackView(views: [
            titleLabel,
            descriptionLabel,
            imageView,
            stepIndicator,
            buttonStack
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func showStep(_ step: Int) {
        currentStep = step
        stepIndicator.stringValue = "\(step + 1) of \(totalSteps)"
        
        switch step {
        case 0:
            titleLabel.stringValue = "Welcome to PresentInk!"
            descriptionLabel.stringValue = "PresentInk is a powerful tool for drawing over your screen during presentations. Let's walk through the main features."
            imageView.image = NSImage(named: "AppIcon")
            backButton.isEnabled = false
            
        case 1:
            titleLabel.stringValue = "Drawing Tools"
            descriptionLabel.stringValue = "Use drawing tools like pen, highlighter, shapes, and text. Turn on drawing mode by either selecting 'Draw' from the system tray menu, or by pressing the shortcut (the default is Option+Shift+D). You can change colors by simply pressing a key (R,G,B,Y,P,O). See the help for all key combinations."
            imageView.image = NSImage(named: "FirstRunDrawing") // Add your screenshot
            backButton.isEnabled = true
            
        case 2:
            titleLabel.stringValue = "Break Timer"
            descriptionLabel.stringValue = "Set up break reminders to easily show the audience when you return to your presentation. Customize the duration, message, and colors to your preference in the settings."
            imageView.image = NSImage(named: "FirstRunBreaktime") // Add your screenshot
            
        case 3:
            titleLabel.stringValue = "Ready to Start!"
            descriptionLabel.stringValue = "You're all set! Access PresentInk from the menu bar and start enhancing your presentations. Check the Help menu for keyboard shortcuts and make sure to check out the settings as you can customize quite some things."
            imageView.image = NSImage(named: "AppIcon") // Add your screenshot
            nextButton.title = "Get Started"
            
        default:
            break
        }
        
        nextButton.isEnabled = true
    }
    
    @objc private func backClicked() {
        if currentStep > 0 {
            showStep(currentStep - 1)
        }
    }
    
    @objc private func nextClicked() {
        if currentStep < totalSteps - 1 {
            showStep(currentStep + 1)
        } else {
            finishWelcome()
        }
    }
    
    @objc private func skipClicked() {
        finishWelcome()
    }
    
    private func finishWelcome() {
        Settings.shared.hasShownWelcome = true
        window?.close()
    }
}
