import Cocoa

class WelcomeWindowController: NSWindowController {
    private var currentStep = 0
    private let totalSteps = 4
    
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let stepIndicator = NSTextField(labelWithString: "")
    private let backButton = NSButton(title: "Back", target: nil, action: nil)
    private let nextButton = NSButton(title: "Next", target: nil, action: nil)
    private let skipButton = NSButton(title: "Skip", target: nil, action: nil)
    
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
        
        backButton.target = self
        backButton.action = #selector(backClicked)
        backButton.isEnabled = false
        
        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        nextButton.keyEquivalent = "\r"
        
        skipButton.target = self
        skipButton.action = #selector(skipClicked)
        
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
            descriptionLabel.stringValue = "Use the toolbar to access different drawing tools like pen, highlighter, shapes, and text. You can customize colors and sizes for each tool."
            imageView.image = NSImage(named: "DrawingTools") // Add your screenshot
            backButton.isEnabled = true
            
        case 2:
            titleLabel.stringValue = "Break Timer"
            descriptionLabel.stringValue = "Set up break reminders to help maintain healthy screen time habits. Customize the duration, message, and colors to your preference."
            imageView.image = NSImage(named: "BreakTimer") // Add your screenshot
            
        case 3:
            titleLabel.stringValue = "Ready to Start!"
            descriptionLabel.stringValue = "You're all set! Access PresentInk from the menu bar and start enhancing your presentations. Check the Help menu for keyboard shortcuts."
            imageView.image = NSImage(named: "MenuBar") // Add your screenshot
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