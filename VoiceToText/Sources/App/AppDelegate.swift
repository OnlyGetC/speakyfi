import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindow: OverlayWindow?
    var settingsWindow: NSWindow?
    var historyWindow: NSWindow?
    var donateWindow: NSWindow?
    var splashWindow: NSWindow?
    var fileTranscriptionWindow: NSWindow?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupOverlayWindow()
        setupHotkeys()
        if !splashDisabled() { showSplash() }

        Task {
            await appState.transcriber.loadModel(appState.selectedLocalModel)
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: t(.menuShow), action: #selector(showOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: t(.menuMode), action: #selector(toggleVAD), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: t(.menuSettings), action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "File Transcription…", action: #selector(showFileTranscriptionAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: t(.menuQuit), action: #selector(quit), keyEquivalent: "q"))
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
        overlayWindow = OverlayWindow(
            appState: appState,
            onSettings: { [weak self] in self?.showSettings() },
            onHistory: { [weak self] in self?.showHistory() },
            onFileTranscription: { [weak self] in self?.showFileTranscription() }
        )
    }

    @objc func showOverlay() {
        overlayWindow?.show()
    }

    // MARK: - Settings Window

    @objc func showSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(
            hotkeys: HotkeyManager.shared,
            appState: appState,
            onClose: { [weak self] in self?.settingsWindow?.orderOut(nil) },
            onDonate: { [weak self] in self?.showDonate() }
        )

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - History Window

    func showHistory() {
        if let existing = historyWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HistoryView(appState: appState, onClose: { [weak self] in
            self?.historyWindow?.orderOut(nil)
        })

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        historyWindow = window
    }

    // MARK: - File Transcription Window

    func showFileTranscription() {
        if let existing = fileTranscriptionWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        let view = FileTranscriptionView(
            appState: appState,
            onClose: { [weak window, weak self] in
                window?.orderOut(nil)
                self?.fileTranscriptionWindow = nil
            }
        )
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        fileTranscriptionWindow = window
    }

    @objc func showFileTranscriptionAction() { showFileTranscription() }

    // MARK: - Donate Window

    func showDonate() {
        if let existing = donateWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 440),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.acceptsMouseMovedEvents = true

        let view = DonateView(onClose: { [weak window, weak self] in
            window?.close()
            self?.donateWindow = nil
        })

        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        donateWindow = window
    }

    // MARK: - Splash

    func showSplash() {
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 300),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.hasShadow = true

        let view = SplashView(
            onDonate: { [weak self] in
                self?.splashWindow?.orderOut(nil)
                self?.showDonate()
            },
            onClose: { [weak self] in
                self?.splashWindow?.orderOut(nil)
            }
        )

        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        splashWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.splashWindow?.orderOut(nil)
        }
    }

    private func splashDisabled() -> Bool {
        let flag = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".speakyfi_nosplash")
        return FileManager.default.fileExists(atPath: flag.path)
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
        guard appState.modelReady || appState.transcriptionProvider == .cloud else { return }
        OutputHandler.shared.rememberFocusedApp()
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
        let language = appState.transcriptionLanguage
        let prompt = appState.promptEnabled ? appState.transcriptionPrompt : nil
        let provider = appState.transcriptionProvider
        let cloudProvider = appState.selectedCloudProvider
        let correctionMode = appState.correctionMode
        let correctionPrompt = appState.correctionPrompt
        let correctionApiProvider = appState.correctionApiProvider
        let correctionOllamaModel = appState.correctionOllamaModel
        let correctionCustomEndpoint = appState.correctionCustomEndpoint

        Task {
            var result: String?

            if provider == .cloud {
                result = await appState.cloudTranscriber.transcribe(
                    audio: audio,
                    provider: cloudProvider,
                    language: language
                )
            } else {
                result = await appState.transcriber.transcribe(
                    audio: audio,
                    language: language,
                    prompt: prompt
                )
            }

            // Постобработка через LLM если включена
            if let raw = result, correctionMode != .off {
                result = await appState.correctionService.correct(
                    text: raw,
                    mode: correctionMode,
                    prompt: correctionPrompt,
                    apiProvider: correctionApiProvider,
                    ollamaModel: correctionOllamaModel,
                    customEndpoint: correctionCustomEndpoint
                )
            }

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
            OutputHandler.shared.rememberFocusedApp()
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
