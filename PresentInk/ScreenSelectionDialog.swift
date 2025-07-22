import Cocoa

class ScreenSelectionDialog {
    static func present(for screens: [NSScreen], onScreenSelected: @escaping (Int?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Select a screen to record"
        alert.informativeText = "Choose which screen you want to record."
        alert.alertStyle = .informational

        // Add a button for each screen
        for (index, screen) in screens.enumerated() {
            let screenDesc = screen.localizedName.isEmpty ? "Screen \(index + 1)" : screen.localizedName
            alert.addButton(withTitle: screenDesc)
        }
        alert.addButton(withTitle: "Cancel")

        // Present the alert modally
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onScreenSelected(0)
        } else if response.rawValue <= NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + screens.count - 1 {
            onScreenSelected(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
        } else {
            onScreenSelected(nil)
        }
    }
}