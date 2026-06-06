import AppKit
import SwiftUI

// NSWindow-подкласс, который принимает фокус (borderless окна по умолчанию не принимают)
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class OverlayWindow: NSWindow {
    private let pillWidth: CGFloat = 340
    private let bottomMargin: CGFloat = 80

    init(appState: AppState, onSettings: @escaping () -> Void, onHistory: @escaping () -> Void, onFileTranscription: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 90),
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
        hidesOnDeactivate = false

        let view = OverlayView(
            appState: appState,
            onClose: { [weak self] in self?.hide() },
            onSettings: onSettings,
            onHistory: onHistory,
            onFileTranscription: onFileTranscription
        )
        contentView = NSHostingView(rootView: view)

        positionAtBottom()
    }

    private func positionAtBottom() {
        guard let screen = NSScreen.main else { return }
        let x = (screen.frame.width - pillWidth) / 2
        let y = screen.visibleFrame.minY + bottomMargin
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show() {
        if !isVisible {
            positionAtBottom()
        }
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
