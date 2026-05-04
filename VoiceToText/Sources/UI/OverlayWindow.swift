import AppKit
import SwiftUI

class OverlayWindow: NSWindow {
    init(appState: AppState) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hasShadow = true

        let view = OverlayView(appState: appState, onClose: { [weak self] in
            self?.hide()
        })
        contentView = NSHostingView(rootView: view)

        center()
        // Сдвигаем немного выше центра экрана — как у SuperWhisper
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 420) / 2
            let y = screen.frame.height * 0.62
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
}
