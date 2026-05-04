import AppKit

class OutputHandler {
    static let shared = OutputHandler()

    func send(text: String) {
        copyToClipboard(text: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.paste()
        }
    }

    private func copyToClipboard(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func paste() {
        let src = CGEventSource(stateID: .hidSystemState)
        // Cmd+V
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
