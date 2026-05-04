import AppKit
import ApplicationServices

class OutputHandler {
    static let shared = OutputHandler()

    private var targetApp: NSRunningApplication?

    func rememberFocusedApp() {
        targetApp = NSWorkspace.shared.frontmostApplication
    }

    func send(text: String) {
        copyToClipboard(text: text)

        guard let app = targetApp else { return }
        let pid = app.processIdentifier

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            app.activate(options: .activateIgnoringOtherApps)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.insertViaAXAPI(pid: pid, text: text) { return }
                self.pasteViaCGEvent()
            }
        }
    }

    // MARK: - AXUIElement

    private func insertViaAXAPI(pid: pid_t, text: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return false }

        let axElement = element as! AXUIElement

        var currentValue: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
        let current = (currentValue as? String) ?? ""

        var rangeValue: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

        var insertPos = current.count
        if let rv = rangeValue {
            var range = CFRange()
            if AXValueGetValue(rv as! AXValue, .cfRange, &range) {
                insertPos = range.location + range.length
            }
        }

        let safePos = min(insertPos, current.utf16.count)
        let idx = current.utf16.index(current.utf16.startIndex, offsetBy: safePos)
        let strIdx = idx.samePosition(in: current) ?? current.endIndex
        let newValue = String(current[..<strIdx]) + text + String(current[strIdx...])

        let setResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newValue as CFString)
        if setResult == .success {
            var newRange = CFRange(location: insertPos + text.count, length: 0)
            if let axRange = AXValueCreate(.cfRange, &newRange) {
                AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, axRange)
            }
            return true
        }
        return false
    }

    // MARK: - CGEvent fallback

    private func pasteViaCGEvent() {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard

    private func copyToClipboard(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
