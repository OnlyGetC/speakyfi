import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindow: OverlayWindow?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupOverlayWindow()
        setupHotkeys()

        // Загружаем модель при старте
        Task {
            await appState.transcriber.loadModel()
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Показать", action: #selector(showOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Режим: PTT / VAD", action: #selector(toggleVAD), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func updateStatusIcon() {
        DispatchQueue.main.async {
            if self.appState.isRecording {
                self.statusItem.button?.title = "🔴"
            } else if self.appState.isTranscribing {
                self.statusItem.button?.title = "⏳"
            } else {
                self.statusItem.button?.title = "🎙"
            }
        }
    }

    // MARK: - Overlay Window

    private func setupOverlayWindow() {
        overlayWindow = OverlayWindow(appState: appState)
    }

    @objc func showOverlay() {
        overlayWindow?.show()
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        HotkeyManager.shared.onPTTPress = { [weak self] in
            self?.startRecording()
        }
        HotkeyManager.shared.onPTTRelease = { [weak self] in
            self?.stopRecording()
        }
        HotkeyManager.shared.onToggleVAD = { [weak self] in
            self?.toggleVAD()
        }
        HotkeyManager.shared.start()
    }

    // MARK: - Recording

    func startRecording() {
        guard appState.modelReady else { return }
        appState.isRecording = true
        updateStatusIcon()
        overlayWindow?.show()
        appState.recorder.startPTT()
    }

    func stopRecording() {
        appState.isRecording = false
        updateStatusIcon()
        appState.recorder.stopPTT { [weak self] audio in
            guard let self, let audio else { return }
            self.transcribe(audio: audio)
        }
    }

    func transcribe(audio: [Float]) {
        appState.isTranscribing = true
        updateStatusIcon()
        Task {
            let result = await appState.transcriber.transcribe(audio: audio)
            await MainActor.run {
                appState.isTranscribing = false
                self.updateStatusIcon()
                if let text = result {
                    appState.addHistory(text: text)
                    OutputHandler.shared.send(text: text)
                }
            }
        }
    }

    // MARK: - Actions

    @objc func toggleVAD() {
        appState.isVADMode.toggle()
        if appState.isVADMode {
            appState.recorder.startVAD { [weak self] audio in
                self?.transcribe(audio: audio)
            }
        } else {
            appState.recorder.stopVAD()
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
