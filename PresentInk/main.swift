//
//  main.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-12.
//

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 2
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
