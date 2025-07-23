//
//  SettingsWindowController.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-10.
//

import Cocoa

class SettingsWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PresentInk"
        window.appearance = NSAppearance(named: .darkAqua)
        
        window.makeKey()
        window.center()
        super.init(window: window)
        self.contentViewController = SettingsContentViewController()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.minSize = NSSize(width: 720, height: 480)
        window?.maxSize = NSSize(width: 720, height: 480)
    }
    required init?(coder: NSCoder) { fatalError() }
}

class SettingsContentViewController: NSViewController {
    enum Category: String, CaseIterable {
        case general = "General"
        case draw = "Drawing"
        case breakTimer = "Break Timer"
        case shortcuts = "Shortcuts"
        case updates = "Updates"
        case about = "About"

        var iconName: String {
            switch self {
            case .general: return "circle"
            case .draw: return "pencil"
            case .breakTimer: return "clock"
            case .shortcuts: return "keyboard"
            case .updates: return "arrow.triangle.2.circlepath"
            case .about: return "info.circle"
            }
        }
    }
    let categories: [Category] = Category.allCases
    var sidebarButtons: [NSButton] = []
    let contentContainer = NSView()
    let generalView = GeneralSettingsView()
    let drawView = DrawSettingsView()
    let aboutView = AboutSettingsView()
    let breakTimerView = BreakTimerSettingsView()
    let shortcutsView = ShortcutsSettingsView()
    let updateSettingsView = UpdateSettingsView()

    override func loadView() {
        self.view = NSView()
        self.view.widthAnchor.constraint(equalToConstant: 720).isActive = true
        self.view.heightAnchor.constraint(equalToConstant: 480).isActive = true
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor =
            NSColor(named: "windowBackgroundColor")?.cgColor
            ?? NSColor.windowBackgroundColor.cgColor
        setupUI()
    }

    func setupUI() {
        let contentView = self.view

        // Sidebar
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor =
            NSColor(calibratedWhite: 0.13, alpha: 1).cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let sidebarStack = NSStackView()
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 8
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false

        for (index, category) in categories.enumerated() {
            let button = SidebarHoverButton()
            button.title = ""
            button.setButtonType(.toggle)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            button.widthAnchor.constraint(equalToConstant: 180).isActive = true

            let customView = SidebarButtonView(
                icon: NSImage(
                    systemSymbolName: category.iconName,
                    accessibilityDescription: nil
                ),
                title: category.rawValue
            )
            customView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(customView)
            NSLayoutConstraint.activate([
                customView.topAnchor.constraint(equalTo: button.topAnchor),
                customView.bottomAnchor.constraint(
                    equalTo: button.bottomAnchor
                ),
                customView.leadingAnchor.constraint(
                    equalTo: button.leadingAnchor
                ),
                customView.trailingAnchor.constraint(
                    equalTo: button.trailingAnchor
                ),
            ])

            button.target = self
            button.action = #selector(sidebarButtonClicked(_:))
            sidebarStack.addArrangedSubview(button)
            sidebarButtons.append(button)
        }
        sidebarButtons.first?.state = .on

        sidebar.addSubview(sidebarStack)
        NSLayoutConstraint.activate([
            sidebarStack.topAnchor.constraint(
                equalTo: sidebar.topAnchor,
                constant: 24
            ),
            sidebarStack.leadingAnchor.constraint(
                equalTo: sidebar.leadingAnchor,
                constant: 8
            ),
            sidebarStack.trailingAnchor.constraint(
                equalTo: sidebar.trailingAnchor,
                constant: -8
            ),
            sidebarStack.bottomAnchor.constraint(
                lessThanOrEqualTo: sidebar.bottomAnchor,
                constant: -24
            ),
            sidebar.widthAnchor.constraint(equalToConstant: 200),
        ])

        // Content container
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        // Main horizontal stack
        let mainStack = NSStackView(views: [sidebar, contentContainer])
        mainStack.orientation = .horizontal
        mainStack.alignment = .top
        mainStack.spacing = 0
        mainStack.distribution = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            ),
            mainStack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            mainStack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            sidebar.widthAnchor.constraint(equalToConstant: 200),
        ])

        // Ensure content container expands to fill remaining width
        contentContainer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )
        contentContainer.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        showCategory(.general)
    }

    @objc func sidebarButtonClicked(_ sender: NSButton) {
        for button in sidebarButtons { button.state = .off }
        sender.state = .on
        let category = categories[sender.tag]
        showCategory(category)
    }

    func showCategory(_ category: Category) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let view: NSView
        switch category {
        case .general: view = generalView
        case .draw: view = drawView
        case .about: view = aboutView
        case .breakTimer: view = breakTimerView
        case .shortcuts: view = shortcutsView
        case .updates:
            view = updateSettingsView
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.bottomAnchor.constraint(
                equalTo: contentContainer.bottomAnchor
            ),
            view.leadingAnchor.constraint(
                equalTo: contentContainer.leadingAnchor
            ),
            view.trailingAnchor.constraint(
                equalTo: contentContainer.trailingAnchor
            ),
        ])

    }
}
