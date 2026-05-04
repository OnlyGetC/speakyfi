import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()

    var onPTTPress: (() -> Void)?
    var onPTTRelease: (() -> Void)?
    var onToggleVAD: (() -> Void)?

    private var monitor: Any?
    private var pttHeld = false

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handle(event: event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(event: NSEvent) {
        switch event.keyCode {
        case 0x76: // F4 — PTT
            if event.type == .keyDown && !pttHeld {
                pttHeld = true
                onPTTPress?()
            } else if event.type == .keyUp && pttHeld {
                pttHeld = false
                onPTTRelease?()
            }
        case 0x60: // F5 — VAD toggle
            if event.type == .keyDown {
                onToggleVAD?()
            }
        default:
            break
        }
    }
}
