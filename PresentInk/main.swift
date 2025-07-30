//
//  main.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-12.
//

import AppKit

let defaults = UserDefaults.standard
defaults.set([UserDefaults.standard.string(forKey: "LanguageCode") ?? "en"], forKey: "AppleLanguages")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
