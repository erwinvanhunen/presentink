//
//  Settings.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-10.
//

import Cocoa
import Foundation
import ServiceManagement
import HotKey

struct SettingsKeyCombo: Codable, Equatable {
    let keyRawValue: UInt32
    let modifiersRawValue: UInt

    var key: Key? { Key(carbonKeyCode: keyRawValue) }
    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiersRawValue) }

    init(key: Key?, modifiers: NSEvent.ModifierFlags) {
        self.keyRawValue = key?.carbonKeyCode ?? 0
        self.modifiersRawValue = modifiers.rawValue
    }
    
    public static func == (lhs: SettingsKeyCombo, rhs: SettingsKeyCombo) -> Bool {
            return lhs.keyRawValue == rhs.keyRawValue &&
                   lhs.modifiersRawValue == rhs.modifiersRawValue
        }
    
}

enum TypingSpeed: Int {
    case slow = 0, normal, fast
}


class Settings {
    static let shared = Settings()
    private let penWidthKey = "penWidth"
    private let defaultColorKey = "defaultColor"
    private let breakMinutesKey = "breakMinutes"
    private let breakMessageKey = "breakMessage"
    private let drawHotkeyKey = "drawHotkey"
    private let screenShotHotkeyKey = "screenShotHotkey"
    private let breakTimerHotkeyKey = "breakTimerHotkey"
    private let textTypeHotkeyKey = "textTypeHotkey"
    private let screenRecordingHotkeyKey = "screenRecordingHotkey"
    private let screenRecordingCroppedHotkeyKey = "screenRecordingCroppedHotkey"
    private let checkForUpdatesOnStartupKey = "checkForUpdatesOnStartup"
    private let lastUpdateCheckKey = "lastUpdateCheck"
    private let typeSpeedIndexKey = "typingSpeedIndex"
    private let showExperimentalFeaturesKey = "showExperimentalFeatures"
    
    private let supportedColors: [String: NSColor] = [
        "red": .red,
        "green": .green,
        "blue": .blue,
        "yellow": .yellow,
        "pink": .magenta,
        "orange": .orange
    ]

    var penWidth: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: penWidthKey)
            return value > 0 ? value : 8  // Default size
        }
        set {
            UserDefaults.standard.set(newValue, forKey: penWidthKey)
        }
    }

    var defaultColor: NSColor {
        get {
            let value = UserDefaults.standard.string(forKey: defaultColorKey) ?? "red"
            return supportedColors[value] ?? .red
        }
        set {
            if let name = supportedColors.first(where: { $0.value == newValue })?.key {
                UserDefaults.standard.set(name, forKey: defaultColorKey)
            }
        }
    }
    
    var drawHotkey: SettingsKeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: drawHotkeyKey),
               let combo = try? JSONDecoder().decode(SettingsKeyCombo.self, from: data) {
                return combo
            }
            return SettingsKeyCombo(key: Key.d, modifiers: [.option, .shift])
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: drawHotkeyKey)
            }
        }
    }
    
    var screenShotHotkey: SettingsKeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: screenShotHotkeyKey),
               let combo = try? JSONDecoder().decode(SettingsKeyCombo.self, from: data) {
                return combo
            }
            return SettingsKeyCombo(key: Key.s, modifiers: [.option, .shift])
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: screenShotHotkeyKey)
            }
        }
    }
    
    var screenRecordingHotkey: SettingsKeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: screenRecordingHotkeyKey),
               let combo = try? JSONDecoder().decode(SettingsKeyCombo.self, from: data) {
                return combo
            }
            return SettingsKeyCombo(key: Key.r, modifiers: [.option, .shift])
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: screenRecordingHotkeyKey)
            }
        }
    }
    
    var screenRecordingCroppedHotkey: SettingsKeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: screenRecordingCroppedHotkeyKey),
               let combo = try? JSONDecoder().decode(SettingsKeyCombo.self, from: data) {
                return combo
            }
            return SettingsKeyCombo(key: Key.r, modifiers: [.control, .shift])
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: screenRecordingCroppedHotkeyKey)
            }
        }
    }
    
    var breakTimerHotkey: SettingsKeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: breakTimerHotkeyKey),
               let combo = try? JSONDecoder().decode(SettingsKeyCombo.self, from: data) {
                return combo
            }
            return SettingsKeyCombo(key: Key.b, modifiers: [.option, .shift])
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: breakTimerHotkeyKey)
            }
        }
    }
    
    var textTypeHotkey: SettingsKeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: textTypeHotkeyKey),
               let combo = try? JSONDecoder().decode(SettingsKeyCombo.self, from: data) {
                return combo
            }
            return SettingsKeyCombo(key: Key.t, modifiers: [.option, .shift])
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: textTypeHotkeyKey)
            }
        }
    }
    
    var breakMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: breakMinutesKey)
            return value > 0 ? value : 10  // Default break length
        }
        set {
            UserDefaults.standard.set(newValue, forKey: breakMinutesKey)
        }
    }
    
    var breakMessage: String {
        get {
            UserDefaults.standard.string(forKey: breakMessageKey) ?? "It's Break Time!"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: breakMessageKey)
        }
    }
    
    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return false
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to update launch at login: \(error)")
                }
            }
        }
    }
    
    var typingSpeed: TypingSpeed {
        get {
            return TypingSpeed(rawValue: UserDefaults.standard.integer(forKey: typeSpeedIndexKey)) ?? .normal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: typeSpeedIndexKey)
        }
    }
    
    var typingSpeedIndex: Int {
        get {
            return typingSpeed.rawValue;
        }
        set {
            UserDefaults.standard.set(newValue, forKey: typeSpeedIndexKey)
        }
    }
    
    var showExperimentalFeatures: Bool {
        get {
            UserDefaults.standard.bool(forKey: showExperimentalFeaturesKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showExperimentalFeaturesKey)
        }
    }
    
    var checkForUpdatesOnStartup: Bool {
        get {
            UserDefaults.standard.bool(forKey: checkForUpdatesOnStartupKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: checkForUpdatesOnStartupKey)
        }
    }
    
    var lastUpdateCheck: Date? {
        get {
            if let data = UserDefaults.standard.data(forKey: lastUpdateCheckKey),
               let date = try? JSONDecoder().decode(Date.self, from: data) {
                return date
            }
            return Date.distantPast
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: lastUpdateCheckKey)
            }
        }
    }
}
