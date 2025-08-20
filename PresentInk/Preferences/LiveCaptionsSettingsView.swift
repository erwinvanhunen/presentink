//
//  LiveCaptionsSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-28.
//


import Cocoa
import Speech

class LiveCaptionsSettingsView: NSView {
    
    private let backgroundView: NSVisualEffectView = {
           let v = NSVisualEffectView()
           v.material = .sidebar
           v.blendingMode = .withinWindow
           v.state = .active
           v.appearance = NSAppearance(named: .vibrantDark)
           v.translatesAutoresizingMaskIntoConstraints = false
           return v
       }()
    
    let sectionLabel: NSTextField = {
        let label = NSTextField(labelWithString: NSLocalizedString("Live captions", comment: "").uppercased())
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    
    private let languageLabel = NSTextField(labelWithString: NSLocalizedString("Language", comment: ""))
    private let languagePopup = NSPopUpButton()
    private let fontSizeLabel = NSTextField(labelWithString: NSLocalizedString("Font Size", comment: ""))
    private let fontSizeSlider = NSSlider()
    private let fontSizeValueLabel = NSTextField(labelWithString: "36")
    private let exampleCaptionLabel = NSTextField(labelWithString: "This is an example caption.")
    
    private let supportedLanguages: [(String, String)] = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Español (España)"),
        ("es-MX", "Español (México)"),
        ("fr-FR", "Français (France)"),
        ("de-DE", "Deutsch (Deutschland)"),
        ("it-IT", "Italiano (Italia)"),
        ("pt-BR", "Português (Brasil)"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
        ("zh-CN", "简体中文"),
        ("zh-TW", "繁體中文"),
        ("nl-NL", "Nederlands"),
        ("ru-RU", "Русский"),
        ("ar-SA", "العربية"),
        ("sv-SE", "Svenska"),
    ]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)

        // Background
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        
        setupUI()
        setupLanguageOptions()
        loadSettings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Configure labels
        languageLabel.font = NSFont.systemFont(ofSize: 12)
        languageLabel.textColor = .white
        languageLabel.alignment = .right
        
        fontSizeLabel.font = NSFont.systemFont(ofSize: 12)
        fontSizeLabel.textColor = .white
        fontSizeLabel.alignment = .right
        
        fontSizeValueLabel.font = NSFont.systemFont(ofSize: 12)
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
        
        exampleCaptionLabel.font = NSFont.systemFont(ofSize: 36)
               exampleCaptionLabel.textColor = NSColor(white: 1, alpha: 0.85)
               exampleCaptionLabel.alignment = .center
               exampleCaptionLabel.lineBreakMode = .byWordWrapping
               exampleCaptionLabel.maximumNumberOfLines = 2
        
        // Create horizontal stacks for each setting
        let languageStack = NSStackView(views: [languageLabel, languagePopup])
        languageStack.orientation = .horizontal
        languageStack.spacing = 12
        languageStack.alignment = .centerY
        
        let fontSizeStack = NSStackView(views: [fontSizeLabel, fontSizeSlider, fontSizeValueLabel])
        fontSizeStack.orientation = .horizontal
        fontSizeStack.spacing = 12
        fontSizeStack.alignment = .centerY
        
        let fieldStack = NSStackView(views: [languageStack, fontSizeStack])
        fieldStack.orientation = .vertical
        fieldStack.spacing = 16
        fieldStack.alignment = .leading
        fieldStack.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = NSStackView(views: [sectionLabel, fieldStack, exampleCaptionLabel])
                mainStack.orientation = .vertical
                mainStack.spacing = 16
                mainStack.alignment = .leading
                mainStack.translatesAutoresizingMaskIntoConstraints = false

                addSubview(mainStack)
        
      
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            mainStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 32
            ),
            mainStack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),
            mainStack.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -32
            ),
            
//            languageLabel.widthAnchor.constraint(equalToConstant: 80),
//            fontSizeLabel.widthAnchor.constraint(equalToConstant: 80),
//            fontSizeSlider.widthAnchor.constraint(equalToConstant: 200),
//            fontSizeValueLabel.widthAnchor.constraint(equalToConstant: 40),
//            exampleCaptionLabel.widthAnchor.constraint(equalToConstant: 320)
        ])
    }
    
    private func setupLanguageOptions() {
        languagePopup.removeAllItems()
        
        // Add supported languages to the popup
      
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
        if let index = languagePopup.itemArray.firstIndex(where: { $0.representedObject as? String == savedLanguage }) {
               languagePopup.selectItem(at: index)
        }
        updateExampleCaption()

    }
    
    @objc private func languageChanged() {
        guard let selectedItem = languagePopup.selectedItem,
              let languageCode = selectedItem.representedObject as? String else { return }
        
        Settings.shared.liveCaptionsLanguage = languageCode
        updateExampleCaption()

    }
    
    @objc private func fontSizeChanged() {
        let fontSize = fontSizeSlider.doubleValue
        fontSizeValueLabel.stringValue = String(Int(fontSize))
        Settings.shared.liveCaptionsFontSize = fontSize
        updateExampleCaption()
    }
    
    private func updateExampleCaption() {
            let fontSize = CGFloat(fontSizeSlider.doubleValue)
            exampleCaptionLabel.font = NSFont.systemFont(ofSize: fontSize)
            // Optionally, change the text based on language
            if let code = languagePopup.selectedItem?.representedObject as? String {
                switch code {
                case "es-ES", "es-MX":
                    exampleCaptionLabel.stringValue = "Este es un ejemplo de subtítulo."
                case "fr-FR":
                    exampleCaptionLabel.stringValue = "Ceci est un exemple de sous-titre."
                case "de-DE":
                    exampleCaptionLabel.stringValue = "Dies ist ein Beispiel-Untertitel."
                case "it-IT":
                    exampleCaptionLabel.stringValue = "Questo è un esempio di sottotitolo."
                case "nl-NL":
                    exampleCaptionLabel.stringValue = "Dit is een voorbeeldondertitel."
                case "ja-JP":
                    exampleCaptionLabel.stringValue = "これは例のキャプションです。"
                case "ko-KR":
                    exampleCaptionLabel.stringValue = "이것은 예시 자막입니다."
                case "zh-CN":
                    exampleCaptionLabel.stringValue = "这是一个示例字幕。"
                case "zh-TW":
                    exampleCaptionLabel.stringValue = "這是一個範例字幕。"
                case "ru-RU":
                    exampleCaptionLabel.stringValue = "Это пример субтитра."
                case "ar-SA":
                    exampleCaptionLabel.stringValue = "هذا مثال على الترجمة."
                default:
                    exampleCaptionLabel.stringValue = "This is an example caption."
                }
            }
        }
}
