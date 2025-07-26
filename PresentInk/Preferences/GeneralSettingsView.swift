//
//  GeneralSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-10.
//
import Cocoa

class GeneralSettingsView: NSView {
    
    var typingSpeedRow: NSStackView?
    
    let sectionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "GENERAL")
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    
    let textTyperLabel: NSTextField = {
        let label = NSTextField(labelWithString: "TEXT TYPER")
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    let launchSwitch = NSSwitch()
    let launchLabel = NSTextField(labelWithString: "Launch at login")
    let typingSpeedLabel = NSTextField(labelWithString: "Typing speed")
      let typingSpeedSelector: NSPopUpButton = {
          let popup = NSPopUpButton()
          popup.addItems(withTitles: ["Slow", "Normal", "Fast"])
          return popup
      }()
    let experimentalLabel = NSTextField(
        labelWithString: "Experimental features (Text Typer, Magnifier)"
    )
    let experimentalSwitch = NSSwitch()
    
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        launchLabel.font = NSFont.systemFont(ofSize: 12)
        experimentalLabel.font = NSFont.systemFont(ofSize: 12)
        typingSpeedLabel.font = NSFont.systemFont(ofSize: 12)

        // Set initial state from settings
        launchSwitch.state = Settings.shared.launchAtLogin ? .on : .off
        launchSwitch.target = self
        launchSwitch.action = #selector(launchSwitchToggled(_:))

        
        typingSpeedSelector.selectItem(at: Settings.shared.typingSpeedIndex)
                typingSpeedSelector.target = self
                typingSpeedSelector.action = #selector(typingSpeedChanged(_:))
        
        let launchRow = NSStackView(views: [launchLabel, launchSwitch])
        launchRow.orientation = .horizontal
        launchRow.alignment = .centerY
        launchRow.spacing = 16

      
        experimentalSwitch.state = Settings.shared.showExperimentalFeatures ? .on : .off
        experimentalSwitch.target = self
        experimentalSwitch.action = #selector(experimentalSwitchToggled(_:))
        
        let experimentalRow = NSStackView(views: [
            experimentalLabel, experimentalSwitch,
        ])
        experimentalRow.orientation = .horizontal
        experimentalRow.alignment = .centerY
        experimentalRow.spacing = 16

        typingSpeedRow = NSStackView(views: [typingSpeedLabel, typingSpeedSelector])
               typingSpeedRow?.orientation = .horizontal
               typingSpeedRow?.alignment = .centerY
               typingSpeedRow?.spacing = 16
        
        textTyperLabel.isHidden = Settings.shared.showExperimentalFeatures == false
        typingSpeedRow?.isHidden = Settings.shared.showExperimentalFeatures == false
        
        let stack = NSStackView(views: [
            sectionLabel, launchRow, experimentalRow, textTyperLabel, typingSpeedRow!
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 32
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -32
            ),
        ])
    }

    @objc func launchSwitchToggled(_ sender: NSSwitch) {
        Settings.shared.launchAtLogin = (sender.state == .on)
    }
    
    @objc func experimentalSwitchToggled(_ sender: NSSwitch) {
        Settings.shared.showExperimentalFeatures = (sender.state == .on)
        NotificationCenter.default.post(name: NSNotification.Name("experimentalFeaturesToggled"), object: nil)
        NotificationCenter.default.post(
            name: NSNotification.Name("HotkeyRecordingStopped"),
            object: nil
        ) // update the hotkeys 
        typingSpeedRow?.isHidden = !Settings.shared.showExperimentalFeatures
        textTyperLabel.isHidden = !Settings.shared.showExperimentalFeatures
    }

    @objc func typingSpeedChanged(_ sender: NSPopUpButton) {
           Settings.shared.typingSpeedIndex = sender.indexOfSelectedItem
       }
    
    required init?(coder: NSCoder) { fatalError() }
}
