// Add this class somewhere in your project
import Cocoa

class ScreenSelectionDialog {
    static func present(for screens: [NSScreen], messageText: String = "Select a screen to record", informativeText : String = "Choose which screen you want to record.",  onScreenSelected: @escaping (Int?) -> Void) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .informational

        for (index, screen) in screens.enumerated() {
            let screenDesc = screen.localizedName.isEmpty ? "Screen \(index + 1)" : screen.localizedName
            alert.addButton(withTitle: screenDesc)
        }
        alert.addButton(withTitle: "Cancel")

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
