// Add this class somewhere in your project
import Cocoa

class ScreenSelectionDialog {
    static func present(for screens: [NSScreen], messageText: String = NSLocalizedString("Select a screen to record", comment: "Default message for Screen selection dialog"), informativeText : String = NSLocalizedString("Choose which screen you want to record", comment: "Default informative screen for Screen selection dialog"),  onScreenSelected: @escaping (Int?) -> Void) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .informational

        for (index, screen) in screens.enumerated() {
            let screenDesc = screen.localizedName.isEmpty ? "Screen \(index + 1)" : screen.localizedName
            alert.addButton(withTitle: screenDesc)
        }
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button in selection dialog"))

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
