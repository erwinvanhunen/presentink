import Carbon
import Cocoa
import Foundation

class TextTyper {
    var delay: useconds_t = 50000  // Default delay in microseconds
    init(typeDelay: useconds_t) {
        delay = typeDelay
    }

    func keyCodeForChar(_ char: Character) -> (CGKeyCode, Bool)? {
        guard
            let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?
                .takeRetainedValue(),
            let layoutData = TISGetInputSourceProperty(
                inputSource,
                kTISPropertyUnicodeKeyLayoutData
            )
        else {
            return nil
        }

        let cfData = unsafeBitCast(layoutData, to: CFData.self)
        guard let keyLayoutPtr = CFDataGetBytePtr(cfData) else {
            return nil
        }

        let keyboardLayout = keyLayoutPtr.withMemoryRebound(
            to: UCKeyboardLayout.self,
            capacity: 1
        ) { $0 }

        let string = String(char)
        var deadKeyState: UInt32 = 0

        for keyCode in 0..<128 {
            var chars: [UniChar] = [0, 0, 0, 0]
            var actualLength: Int = 0

            // Try without modifiers first
            var result = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                0,  // No modifier
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &actualLength,
                &chars
            )

            if result == noErr,
                String(utf16CodeUnits: chars, count: actualLength) == string
            {
                return (CGKeyCode(keyCode), false)  // No shift
            }

            // Reset and try with Shift modifier
            deadKeyState = 0
            chars = [0, 0, 0, 0]
            actualLength = 0

            result = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                UInt32(shiftKey) >> 8,  // Shift modifier (corrected)
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &actualLength,
                &chars
            )

            if result == noErr,
                String(utf16CodeUnits: chars, count: actualLength) == string
            {
                return (CGKeyCode(keyCode), true)  // Shift needed
            }
        }

        return nil
    }

    // Map characters to key codes (a limited demo map for basic Latin letters and space)
    let keyCodeMap: [Character: CGKeyCode] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
        "i": 34,
        "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12,
        "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16,
        "z": 6,
        "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4,
        "I": 34,
        "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12,
        "R": 15, "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16,
        "Z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
        "8": 28, "9": 25,
        " ": 49, "\n": 36, "\r": 36, ".": 47, ",": 43, "-": 27, ";": 41,
        ":": 39,
        "!": 18, "?": 44, "'": 39, "\"": 39, "=": 24, "[": 33, "]": 30,
    ]

    let arrowKeyCodes: [String: CGKeyCode] = [
        "left": 123,
        "right": 124,
        "down": 125,
        "up": 126,
        "enter": 36,
        "tab": 48,
    ]

    let symbolMap: [Character: (CGKeyCode, CGEventFlags)] = [
        "!": (18, .maskShift),  // Shift+1
        "@": (19, .maskShift),  // Shift+2
        "#": (20, .maskShift),  // Shift+3
        "$": (21, .maskShift),  // Shift+4
        "%": (23, .maskShift),  // Shift+5
        "^": (22, .maskShift),  // Shift+6
        "&": (26, .maskShift),  // Shift+7
        "*": (28, .maskShift),  // Shift+8
        "(": (25, .maskShift),  // Shift+9
        ")": (29, .maskShift),  // Shift+0
        "_": (27, .maskShift),  // Shift+-
        "+": (24, .maskShift),  // Shift+=
        "{": (33, .maskShift),  // Shift+[
        "}": (30, .maskShift),  // Shift+]
        "|": (42, .maskShift),  // Shift+\
        ":": (41, .maskShift),  // Shift+;
        "\"": (39, .maskShift),  // Shift+'
        "<": (43, .maskShift),  // Shift+,
        ">": (47, .maskShift),  // Shift+.
        "?": (44, .maskShift),  // Shift+/
        // ...Add more as needed...
    ]

    private func sendKey(char: Character) {
         guard let (keyCode, needsShift) = keyCodeForChar(char) else {
             print("Unsupported character: \(char)")
             return
         }
         var flags: CGEventFlags = []
         if needsShift {
             flags.insert(.maskShift)
         }
         
         sendKeyCode(keyCode: keyCode, flags: flags)
     }    //
    //    // Send a key press
    //    private func sendKey(char: Character) {
    //
    //        if let (keyCode, flags) = symbolMap[char] {
    //            // For symbols, use mapped keycode and modifier
    //            let keyDown = CGEvent(
    //                keyboardEventSource: nil,
    //                virtualKey: keyCode,
    //                keyDown: true
    //            )
    //            keyDown?.flags = flags
    //            keyDown?.post(tap: .cghidEventTap)
    //            let keyUp = CGEvent(
    //                keyboardEventSource: nil,
    //                virtualKey: keyCode,
    //                keyDown: false
    //            )
    //            keyUp?.flags = flags
    //            keyUp?.post(tap: .cghidEventTap)
    //        } else if let keyCode = keyCodeForChar(char) {
    //            // For basic characters, use existing logic
    //            var flags: CGEventFlags = []
    //            if char.isUppercase {
    //                flags.insert(.maskShift)
    //            }
    //            let keyDown = CGEvent(
    //                keyboardEventSource: nil,
    //                virtualKey: keyCode,
    //                keyDown: true
    //            )
    //            keyDown?.flags = flags
    //            keyDown?.post(tap: .cghidEventTap)
    //            let keyUp = CGEvent(
    //                keyboardEventSource: nil,
    //                virtualKey: keyCode,
    //                keyDown: false
    //            )
    //            keyUp?.flags = flags
    //            keyUp?.post(tap: .cghidEventTap)
    //        } else {
    //            print("Unsupported character: \(char)")
    //        }
    //    }

    private func sendReturn() {
        let keyCode: CGKeyCode = 36
        sendKeyCode(keyCode: keyCode)
    }

    private func sendTab() {
        let keyCode: CGKeyCode = 43
        sendKeyCode(keyCode: keyCode)
    }

    private func sendKeyCode(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        )
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        )
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }


    private func sendArrow(_ direction: String) {
        let arrowKeyCodes: [String: CGKeyCode] = [
            "left": 123, "right": 124, "down": 125, "up": 126,
        ]
        guard let keyCode = arrowKeyCodes[direction] else { return }
        let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        )
        keyDown?.post(tap: .cghidEventTap)
        let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        )
        keyUp?.post(tap: .cghidEventTap)
    }

    func typeText(textToType: String, withDelay delay: useconds_t = 50000) {
        self.delay = delay
        // Accessibility permission check
        let trusted = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
        if !trusted {
            print(
                "Please enable accessibility permissions for this app in System Settings > Privacy & Security > Accessibility."
            )
            exit(1)
        }

        typeStringWithTags(textToType)
    }

    func typeStringWithTags(_ string: String) {
        let nsString = string as NSString
        let tagPattern = #"\[([a-z]+(?::\d+)?)\]"#
        let regex = try! NSRegularExpression(
            pattern: tagPattern,
            options: []
        )
        let matches = regex.matches(
            in: string,
            options: [],
            range: NSRange(location: 0, length: nsString.length)
        )
        var lastLocation = 0

        for match in matches {
            let matchRange = match.range
            let textRange = NSRange(
                location: lastLocation,
                length: matchRange.location - lastLocation
            )
            if textRange.length > 0 {
                let beforeText = nsString.substring(with: textRange)

                for char in beforeText {
                    if char != "\n" && char != "\r" {
                        sendKey(char: char)
                        usleep(delay)
                    }
                }
            }

            if let tagRange = Range(match.range(at: 1), in: string) {
                let tag = String(string[tagRange])
                switch tag {
                case "left", "right", "up", "down":
                    sendArrow(tag)
                    usleep(delay)
                case "return", "enter", "newline":
                    sendReturn()
                    usleep(delay)
                case "tab":
                    sendTab()
                    usleep(delay)
                default:
                    if tag.starts(with: "pause:") {
                        let parts = tag.split(separator: ":")
                        if parts.count == 2, let seconds = Int(parts[1]) {
                            sleep(UInt32(seconds))
                        }
                    }
                }
            }
            lastLocation = matchRange.location + matchRange.length
        }
        if lastLocation < nsString.length {
            let tailText = nsString.substring(from: lastLocation)
            for char in tailText {
                if char != "\n" && char != "\r" {
                    sendKey(char: char)
                    usleep(delay)
                }
            }
        }
    }

}
