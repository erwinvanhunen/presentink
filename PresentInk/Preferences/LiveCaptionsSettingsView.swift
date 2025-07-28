//
//  LiveCaptionsSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-28.
//


import Cocoa
import Speech

class LiveCaptionsSettingsView: NSView {
    private let languageLabel = NSTextField(labelWithString: "Language:")
    private let languagePopup = NSPopUpButton()
    private let fontSizeLabel = NSTextField(labelWithString: "Font Size:")
    private let fontSizeSlider = NSSlider()
    private let fontSizeValueLabel = NSTextField(labelWithString: "36")
    
    private let supportedLanguages: [(String, String)] = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr-FR", "French (France)"),
        ("de-DE", "German (Germany)"),
        ("it-IT", "Italian (Italy)"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("nl-NL", "Dutch"),
        ("ru-RU", "Russian"),
        ("ar-SA", "Arabic")
    ]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadSettings()
        setupLanguageOptions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Configure labels
        languageLabel.font = NSFont.systemFont(ofSize: 14)
        languageLabel.textColor = .white
        languageLabel.alignment = .right
        
        fontSizeLabel.font = NSFont.systemFont(ofSize: 14)
        fontSizeLabel.textColor = .white
        fontSizeLabel.alignment = .right
        
        fontSizeValueLabel.font = NSFont.systemFont(ofSize: 14)
        fontSizeValueLabel.textColor = NSColor(white: 1, alpha: 0.7)
        fontSizeValueLabel.alignment = .left
        
        // Configure font size slider
        fontSizeSlider.minValue = 16
        fontSizeSlider.maxValue = 72
        fontSizeSlider.doubleValue = 36
        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged)
        
        // Configure popup button
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        
        // Create horizontal stacks for each setting
        let languageStack = NSStackView(views: [languageLabel, languagePopup])
        languageStack.orientation = .horizontal
        languageStack.spacing = 12
        languageStack.alignment = .centerY
        
        let fontSizeStack = NSStackView(views: [fontSizeLabel, fontSizeSlider, fontSizeValueLabel])
        fontSizeStack.orientation = .horizontal
        fontSizeStack.spacing = 12
        fontSizeStack.alignment = .centerY
        
        // Main vertical stack
        let mainStack = NSStackView(views: [languageStack, fontSizeStack])
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            
            languageLabel.widthAnchor.constraint(equalToConstant: 80),
            fontSizeLabel.widthAnchor.constraint(equalToConstant: 80),
            fontSizeSlider.widthAnchor.constraint(equalToConstant: 200),
            fontSizeValueLabel.widthAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupLanguageOptions() {
        languagePopup.removeAllItems()
        
        for (code, name) in supportedLanguages {
            if SFSpeechRecognizer.supportedLocales().contains(Locale(identifier: code)) {
                languagePopup.addItem(withTitle: name)
                languagePopup.lastItem?.representedObject = code
            }
        }
    }
    
    private func loadSettings() {
        let savedLanguage = Settings.shared.liveCaptionsLanguage
        let savedFontSize = Settings.shared.liveCaptionsFontSize
      
        fontSizeSlider.doubleValue = savedFontSize
       
        fontSizeValueLabel.stringValue = String(Int(fontSizeSlider.doubleValue))
        
        // Select the saved language in popup
        for item in languagePopup.itemArray {
            if item.representedObject as? String == savedLanguage {
                languagePopup.select(item)
                break
            }
        }
    }
    
    @objc private func languageChanged() {
        guard let selectedItem = languagePopup.selectedItem,
              let languageCode = selectedItem.representedObject as? String else { return }
        
        Settings.shared.liveCaptionsLanguage = languageCode
    }
    
    @objc private func fontSizeChanged() {
        let fontSize = fontSizeSlider.doubleValue
        fontSizeValueLabel.stringValue = String(Int(fontSize))
        Settings.shared.liveCaptionsFontSize = fontSize
    }
}
