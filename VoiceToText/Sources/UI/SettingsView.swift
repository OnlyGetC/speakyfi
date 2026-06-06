import SwiftUI
import AppKit

// MARK: - Settings sections

enum SettingsSection: String, CaseIterable, Identifiable {
    case hotkeys    = "hotkeys"
    case model      = "model"
    case language   = "language"
    case prompt     = "prompt"
    case correction = "correction"
    case interface_ = "interface"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hotkeys:    return t(.sectionHotkeys)
        case .model:      return t(.sectionModel)
        case .language:   return t(.sectionLanguage)
        case .prompt:     return t(.sectionPrompt)
        case .correction: return t(.sectionCorrection)
        case .interface_: return t(.sectionInterface)
        }
    }

    var shortLabel: String {
        switch self {
        case .hotkeys:    return "[HOTKEYS]"
        case .model:      return "[MODEL]"
        case .language:   return "[LANG]"
        case .prompt:     return "[PROMPT]"
        case .correction: return "[CORRECT]"
        case .interface_: return "[UI]"
        }
    }

    var icon: String {
        switch self {
        case .hotkeys:    return "keyboard"
        case .model:      return "cpu"
        case .language:   return "globe"
        case .prompt:     return "text.bubble"
        case .correction: return "wand.and.stars"
        case .interface_: return "textformat"
        }
    }

    var info: String {
        switch self {
        case .hotkeys:    return t(.infoHotkeys)
        case .model:      return t(.infoModel)
        case .language:   return t(.infoLanguage)
        case .prompt:     return t(.infoPrompt)
        case .correction: return t(.infoCorrection)
        case .interface_: return t(.infoInterface)
        }
    }
}

// MARK: - HotkeyRecorderButton

struct HotkeyRecorderButton: View {
    let label: String
    let isForPTT: Bool
    @Binding var binding: HotkeyBinding
    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var flagMonitor: Any?

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.amber(13))
                .foregroundColor(Amber.dim)
                .frame(minWidth: 130, alignment: .leading)
            Spacer()
            Button(action: toggleRecording) {
                Text(isRecording ? t(.hotkeyPressKey) : binding.displayString)
                    .font(.amber(13))
                    .foregroundColor(isRecording ? Amber.hot : Amber.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Rectangle()
                            .fill(isRecording ? Amber.hot.opacity(0.08) : Amber.faint)
                    )
                    .overlay(
                        Rectangle()
                            .stroke(isRecording ? Amber.hot : Amber.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isRecording)
            Button(action: resetToDefault) {
                Text("[RST]")
                    .font(.amber(11))
                    .foregroundColor(binding == defaultBinding ? Amber.faint : Amber.dim)
            }
            .buttonStyle(.plain)
            .disabled(binding == defaultBinding)
            .help(t(.hotkeyReset))
        }
    }

    private var defaultBinding: HotkeyBinding { isForPTT ? .defaultPTT : .defaultVAD }

    private func toggleRecording() { isRecording ? stopRecording() : startRecording() }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
            if event.keyCode == 0x35 && mods == 0 { self.stopRecording(); return nil }
            self.binding = HotkeyBinding(keyCode: event.keyCode, modifiers: mods)
            self.stopRecording()
            return nil
        }
        var capturedFlags: NSEvent.ModifierFlags = []
        flagMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let cur = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if !cur.isEmpty { capturedFlags = cur }
            else if !capturedFlags.isEmpty {
                self.binding = HotkeyBinding(keyCode: HotkeyBinding.modifierOnly, modifiers: capturedFlags.rawValue)
                self.stopRecording()
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = keyMonitor  { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = flagMonitor { NSEvent.removeMonitor(m); flagMonitor = nil }
    }

    private func resetToDefault() { binding = defaultBinding }
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var hotkeys: HotkeyManager
    @ObservedObject var appState: AppState
    var onClose: () -> Void
    var onDonate: () -> Void

    @ObservedObject private var l10n = L10nState.shared
    @State private var selectedSection: SettingsSection = .hotkeys

    var body: some View {
        ZStack {
            // Background
            Amber.bg

            // Scanlines
            ScanlineOverlay()

            VStack(spacing: 0) {
                // Header stripe
                headerBar
                    .background(Amber.bgHeader)
                AmberDivider()

                HStack(spacing: 0) {
                    // Sidebar
                    sidebarView
                        .frame(width: 150)

                    Rectangle()
                        .fill(Amber.border)
                        .frame(width: 1)

                    // Section content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            sectionContent(selectedSection)
                                .padding(20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 700, height: 520)
        .amberBorder()
        .shadow(color: Amber.primary.opacity(0.12), radius: 20, x: 0, y: 6)
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 0) {
            Text("SPEAKYFI")
                .font(.amber(13, weight: .bold))
                .foregroundColor(Amber.bright)
                .amberGlow(5)
                .padding(.leading, 10)

            Text(" [CONFIG]")
                .font(.amber(11))
                .foregroundColor(Amber.dim)

            Spacer()

            Button(action: onClose) {
                Text("[X]")
                    .font(.amber(13, weight: .bold))
                    .foregroundColor(Amber.bright)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Amber.bgHeader)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar title
            HStack {
                Text("// MENU")
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            AmberDivider()

            // Menu items
            VStack(spacing: 0) {
                ForEach(SettingsSection.allCases) { section in
                    sidebarItem(section)
                    Rectangle()
                        .fill(Amber.borderFaint)
                        .frame(height: 1)
                }
            }

            Spacer()

            AmberDivider()

            // Donate button
            Button(action: onDonate) {
                Text("[SUPPORT]")
                    .font(.amber(12))
                    .foregroundColor(Amber.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func sidebarItem(_ section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        return Button(action: { selectedSection = section }) {
            HStack(spacing: 0) {
                // Left accent border for active item
                Rectangle()
                    .fill(isSelected ? Amber.hot : Color.clear)
                    .frame(width: 2)

                Text(section.shortLabel)
                    .font(.amber(12, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Amber.bright : Amber.dim)
                    .padding(.leading, 8)
                    .padding(.vertical, 9)

                Spacer()
            }
            .background(isSelected ? Amber.bg : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section title

    private func sectionTitle(_ title: String, info: String) -> some View {
        HStack(spacing: 8) {
            Text("// \(title.uppercased()) \(String(repeating: "─", count: max(0, 28 - title.count)))")
                .font(.amber(12, weight: .bold))
                .foregroundColor(Amber.primary)
                .amberGlow(2)
            AmberInfoButton(text: info)
            Spacer()
        }
        .padding(.bottom, 12)
    }

    // MARK: - Section content router

    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .hotkeys:    hotkeysSection
        case .model:      modelSection
        case .language:   languageSection
        case .prompt:     promptSection
        case .correction: correctionSection
        case .interface_: interfaceSection
        }
    }

    // MARK: Hotkeys

    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.sectionHotkeys), info: SettingsSection.hotkeys.info)
            HotkeyRecorderButton(label: t(.hotkeyPTT), isForPTT: true,  binding: $hotkeys.pttBinding)
            AmberDivider()
            HotkeyRecorderButton(label: t(.hotkeyVAD), isForPTT: false, binding: $hotkeys.vadBinding)
            Text(t(.hotkeyHint))
                .font(.amber(11))
                .foregroundColor(Amber.faint)
                .padding(.top, 4)
        }
    }

    // MARK: Model

    @ObservedObject private var modelManager = ModelManager.shared
    @State private var downloadingModel: LocalWhisperModel? = nil
    @State private var downloadProgress: Double = 0
    @State private var downloadLabel: String = ""
    @State private var apiKeyInput: String = ""
    @State private var showApiKey: Bool = false

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.sectionModel), info: SettingsSection.model.info)

            HStack(spacing: 0) {
                providerTab(label: t(.modelLocal), isSelected: appState.transcriptionProvider == .local) {
                    appState.transcriptionProvider = .local
                }
                Rectangle()
                    .fill(Amber.border)
                    .frame(width: 1, height: 26)
                providerTab(label: t(.modelCloud), isSelected: appState.transcriptionProvider == .cloud) {
                    appState.transcriptionProvider = .cloud
                }
            }
            .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))

            if appState.transcriptionProvider == .local {
                localModelSection
            } else {
                cloudModelSection
            }
        }
        .onAppear {
            modelManager.refreshDownloadedStatus()
            loadApiKeyInput()
        }
    }

    private var localModelSection: some View {
        VStack(spacing: 1) {
            ForEach(LocalWhisperModel.allCases) { model in
                localModelRow(model)
                Rectangle().fill(Amber.borderFaint).frame(height: 1)
            }
            if downloadingModel != nil {
                VStack(spacing: 6) {
                    HStack {
                        Text(downloadLabel)
                            .font(.amber(12))
                            .foregroundColor(Amber.dim)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.amber(12, weight: .bold))
                            .foregroundColor(Amber.hot)
                    }
                    asciiProgressBar(progress: downloadProgress)
                }
                .padding(.top, 6)
            }
        }
    }

    private func localModelRow(_ model: LocalWhisperModel) -> some View {
        let status = modelManager.modelStatuses[model] ?? .notDownloaded
        let isSelected = appState.transcriptionProvider == .local && appState.selectedLocalModel == model
        let isDownloaded = status == .downloaded
        let isDownloading = downloadingModel == model

        return HStack(spacing: 10) {
            // Selection indicator
            Text(isSelected ? "[*]" : "[ ]")
                .font(.amber(12))
                .foregroundColor(isSelected ? Amber.hot : Amber.faint)
                .onTapGesture { if isDownloaded && !isDownloading { appState.switchLocalModel(to: model) } }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName.uppercased())
                        .font(.amber(13))
                        .foregroundColor(isDownloaded ? Amber.primary : Amber.faint)
                    if appState.isModelSwitching && isSelected {
                        Text(t(.modelLoading).uppercased())
                            .font(.amber(11))
                            .foregroundColor(Amber.warn)
                    }
                }
                Text(model.description)
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
            }
            Spacer()
            if isDownloading {
                Text("......")
                    .font(.amber(9))
                    .foregroundColor(Amber.hot)
            } else if isDownloaded {
                if isSelected {
                    Text("[ACTIVE]")
                        .font(.amber(11, weight: .bold))
                        .foregroundColor(Amber.ok)
                } else {
                    Button(t(.modelSelect).uppercased()) { appState.switchLocalModel(to: model) }
                        .font(.amber(11))
                        .foregroundColor(Amber.dim)
                        .buttonStyle(.plain)
                }
            } else {
                Button("[DOWNLOAD]") { startDownload(model) }
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Amber.faint : Color.clear)
    }

    private func asciiProgressBar(progress: Double) -> some View {
        GeometryReader { geo in
            let total = Int((geo.size.width - 20) / 7)
            let filled = Int(Double(total) * progress)
            let empty = max(0, total - filled)
            HStack(spacing: 0) {
                Text("[")
                    .font(.amber(12))
                    .foregroundColor(Amber.dim)
                Text(String(repeating: "█", count: filled))
                    .font(.amber(12))
                    .foregroundColor(Amber.hot)
                    .amberGlow(2)
                Text(String(repeating: "─", count: empty))
                    .font(.amber(12))
                    .foregroundColor(Amber.faint)
                Text("]")
                    .font(.amber(12))
                    .foregroundColor(Amber.dim)
                Text(" \(Int(progress * 100))%")
                    .font(.amber(12, weight: .bold))
                    .foregroundColor(Amber.hot)
            }
            .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(height: 14)
    }

    private func startDownload(_ model: LocalWhisperModel) {
        guard downloadingModel == nil else { return }
        downloadingModel = model; downloadProgress = 0; downloadLabel = t(.correctionLoadingModel)
        Task {
            await ModelManager.shared.downloadModel(model) { progress, label in
                DispatchQueue.main.async { self.downloadProgress = progress; self.downloadLabel = label }
            }
            DispatchQueue.main.async { self.downloadingModel = nil; self.modelManager.refreshDownloadedStatus() }
        }
    }

    private var cloudModelSection: some View {
        VStack(spacing: 10) {
            VStack(spacing: 1) {
                ForEach(CloudProvider.allCases) { provider in
                    cloudProviderRow(provider)
                    Rectangle().fill(Amber.borderFaint).frame(height: 1)
                }
            }
            AmberDivider()
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t(.modelApiKeyFor)) \(appState.selectedCloudProvider.displayName)".uppercased())
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                HStack(spacing: 8) {
                    Group {
                        if showApiKey { TextField("sk-...", text: $apiKeyInput) }
                        else { SecureField("sk-...", text: $apiKeyInput) }
                    }
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Amber.faint)
                    .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                    .colorScheme(.dark)
                    Button(action: { showApiKey.toggle() }) {
                        Text(showApiKey ? "[HIDE]" : "[SHOW]")
                            .font(.amber(11))
                            .foregroundColor(Amber.dim)
                    }.buttonStyle(.plain)
                    Button(t(.modelSave).uppercased()) { saveApiKey() }
                        .font(.amber(11, weight: .bold))
                        .foregroundColor(Amber.primary)
                        .buttonStyle(.plain)
                }
                Text(t(.modelKeychainNote))
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
            }
        }
    }

    private func cloudProviderRow(_ provider: CloudProvider) -> some View {
        let isSelected = appState.selectedCloudProvider == provider
        return HStack(spacing: 10) {
            Text(isSelected ? "[*]" : "[ ]")
                .font(.amber(12))
                .foregroundColor(isSelected ? Amber.hot : Amber.faint)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName.uppercased())
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                Text(provider.description)
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
            }
            Spacer()
            if KeychainHelper.load(key: provider.keychainKey) != nil {
                Text("[KEY·SET]")
                    .font(.amber(11))
                    .foregroundColor(Amber.ok)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Amber.faint : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { appState.selectedCloudProvider = provider; loadApiKeyInput() }
    }

    private func loadApiKeyInput() {
        apiKeyInput = KeychainHelper.load(key: appState.selectedCloudProvider.keychainKey) ?? ""
    }
    private func saveApiKey() {
        if apiKeyInput.isEmpty { KeychainHelper.delete(key: appState.selectedCloudProvider.keychainKey) }
        else { KeychainHelper.save(key: appState.selectedCloudProvider.keychainKey, value: apiKeyInput) }
    }

    // MARK: Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.langTitle), info: SettingsSection.language.info)
            HStack {
                Text(t(.interfaceLanguageLabel).uppercased())
                    .font(.amber(13))
                    .foregroundColor(Amber.dim)
                Spacer()
                Picker("", selection: $appState.transcriptionLanguage) {
                    ForEach(WhisperLanguage.all) { lang in Text(lang.name).tag(lang.id) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
                .colorScheme(.dark)
            }
            Text(t(.langHint))
                .font(.amber(11))
                .foregroundColor(Amber.faint)
        }
    }

    // MARK: Prompt

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(t(.promptTitle), info: SettingsSection.prompt.info)
                Spacer()
                Toggle("", isOn: $appState.promptEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .tint(Amber.hot)
            }
            if appState.promptEnabled {
                TextEditor(text: $appState.transcriptionPrompt)
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                    .scrollContentBackground(.hidden)
                    .background(Amber.faint)
                    .frame(minHeight: 100)
                    .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                HStack {
                    Spacer()
                    Button(t(.promptReset).uppercased()) {
                        appState.transcriptionPrompt = t(.promptDefaultText)
                    }
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                    .buttonStyle(.plain)
                }
            } else {
                Text(t(.promptDisabledHint))
                    .font(.amber(12))
                    .foregroundColor(Amber.faint)
            }
        }
    }

    // MARK: Correction

    @ObservedObject private var ollamaManager = OllamaManager.shared
    @State private var correctionApiKeyInput: String = ""
    @State private var showCorrectionApiKey: Bool = false

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(t(.correctionTitle), info: SettingsSection.correction.info)

            // Mode selection
            VStack(spacing: 1) {
                correctionModeRow(.off)
                Rectangle().fill(Amber.borderFaint).frame(height: 1)
                correctionModeRow(.ollama)
                Rectangle().fill(Amber.borderFaint).frame(height: 1)
                correctionModeRow(.api)
            }
            .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))

            if appState.correctionMode != .off {
                AmberDivider()
            }

            // Ollama settings
            if appState.correctionMode == .ollama {
                ollamaCorrectionSection
            }

            // API settings
            if appState.correctionMode == .api {
                apiCorrectionSection
            }

            // Prompt field
            if appState.correctionMode != .off {
                AmberDivider()
                correctionPromptSection
            }
        }
        .onAppear { loadCorrectionApiKey() }
        .onChange(of: appState.correctionApiProvider) { _ in loadCorrectionApiKey() }
    }

    private func correctionModeRow(_ mode: CorrectionMode) -> some View {
        let isSelected = appState.correctionMode == mode
        return HStack(spacing: 10) {
            Text(isSelected ? "[*]" : "[ ]")
                .font(.amber(12))
                .foregroundColor(isSelected ? Amber.hot : Amber.faint)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName.uppercased())
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                Text(correctionModeDescription(mode))
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Amber.faint : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { appState.correctionMode = mode }
    }

    private func correctionModeDescription(_ mode: CorrectionMode) -> String {
        switch mode {
        case .off:    return t(.correctionOffDescription)
        case .ollama: return t(.correctionOllamaDescription)
        case .api:    return t(.correctionApiDescription)
        }
    }

    private var ollamaCorrectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("OLLAMA")
                            .font(.amber(13, weight: .bold))
                            .foregroundColor(Amber.primary)
                        Text("· \(ollamaStatusLabel.uppercased())")
                            .font(.amber(11))
                            .foregroundColor(ollamaStatusAmberColor)
                    }
                    Text("\(t(.correctionOllamaModelLabel)) \(OllamaManager.defaultModel) (~1.3 GB)".uppercased())
                        .font(.amber(11))
                        .foregroundColor(Amber.faint)
                }
                Spacer()

                if ollamaManager.isInstalled {
                    Toggle("", isOn: $ollamaManager.enabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.85)
                        .tint(Amber.hot)
                        .disabled(isOllamaToggleDisabled)
                }
            }

            switch ollamaManager.installStatus {
            case .notInstalled:
                Button(action: { Task { await ollamaManager.install() } }) {
                    Text("[INSTALL OLLAMA]")
                        .font(.amber(12))
                        .foregroundColor(Amber.bright)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

            case .installing(let progress, let label):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(label.uppercased())
                            .font(.amber(11))
                            .foregroundColor(Amber.dim)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.amber(11, weight: .bold))
                            .foregroundColor(Amber.hot)
                    }
                    asciiProgressBar(progress: progress)
                }

            case .installed:
                switch ollamaManager.modelStatus {
                case .notPulled:
                    if case .running = ollamaManager.serverStatus {
                        Button(action: { Task { await ollamaManager.pullModel() } }) {
                            Text("[DOWNLOAD \(OllamaManager.defaultModel.uppercased())]")
                                .font(.amber(12))
                                .foregroundColor(Amber.bright)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                case .pulling(let progress):
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t(.correctionLoadingModel).uppercased())
                                .font(.amber(11))
                                .foregroundColor(Amber.dim)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.amber(11, weight: .bold))
                                .foregroundColor(Amber.hot)
                        }
                        asciiProgressBar(progress: progress)
                    }
                case .ready:
                    EmptyView()
                case .error(let msg):
                    Text((t(.correctionModelError) + msg).uppercased())
                        .font(.amber(11))
                        .foregroundColor(Amber.rec)
                }

            case .error(let msg):
                Text((t(.correctionInstallError) + msg).uppercased())
                    .font(.amber(11))
                    .foregroundColor(Amber.rec)
            }
        }
    }

    private var ollamaStatusLabel: String {
        switch ollamaManager.installStatus {
        case .notInstalled:        return t(.correctionOllamaStatusNotInstalled)
        case .installing:          return t(.correctionOllamaStatusInstalling)
        case .error:               return t(.correctionOllamaStatusInstallError)
        case .installed:
            switch ollamaManager.serverStatus {
            case .stopped:         return t(.correctionOllamaStatusStopped)
            case .starting:        return t(.correctionOllamaStatusStarting)
            case .stopping:        return t(.correctionOllamaStatusStopping)
            case .error:           return t(.correctionOllamaStatusServerError)
            case .running:
                switch ollamaManager.modelStatus {
                case .ready:       return t(.correctionOllamaStatusReady)
                case .pulling:     return t(.correctionOllamaStatusPulling)
                case .notPulled:   return t(.correctionOllamaStatusNotPulled)
                case .error:       return t(.correctionOllamaStatusModelError)
                }
            }
        }
    }

    private var ollamaStatusAmberColor: Color {
        switch ollamaManager.installStatus {
        case .notInstalled: return Amber.faint
        case .installing:   return Amber.warn
        case .error:        return Amber.rec
        case .installed:
            if case .running = ollamaManager.serverStatus,
               case .ready = ollamaManager.modelStatus { return Amber.ok }
            if case .stopped = ollamaManager.serverStatus { return Amber.faint }
            if case .error = ollamaManager.serverStatus { return Amber.rec }
            return Amber.warn
        }
    }

    private var ollamaStatusColor: Color { ollamaStatusAmberColor }

    private var isOllamaToggleDisabled: Bool {
        switch ollamaManager.serverStatus {
        case .starting, .stopping: return true
        default: return false
        }
    }

    private var apiCorrectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Provider selection
            HStack(spacing: 0) {
                ForEach(CorrectionApiProvider.allCases) { provider in
                    Button(action: { appState.correctionApiProvider = provider }) {
                        Text(provider.displayName.uppercased())
                            .font(.amber(12, weight: appState.correctionApiProvider == provider ? .bold : .regular))
                            .foregroundColor(appState.correctionApiProvider == provider ? Amber.bright : Amber.dim)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(appState.correctionApiProvider == provider ? Amber.faint : Color.clear)
                    }
                    .buttonStyle(.plain)
                    if provider != CorrectionApiProvider.allCases.last {
                        Rectangle().fill(Amber.border).frame(width: 1, height: 26)
                    }
                }
            }
            .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))

            // Custom endpoint
            if appState.correctionApiProvider == .custom {
                TextField("https://...", text: $appState.correctionCustomEndpoint)
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Amber.faint)
                    .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                    .colorScheme(.dark)
            }

            // API key
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t(.correctionApiKeyLabel)) (\(appState.correctionApiProvider.displayName))".uppercased())
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                HStack(spacing: 8) {
                    Group {
                        if showCorrectionApiKey { TextField("sk-...", text: $correctionApiKeyInput) }
                        else { SecureField("sk-...", text: $correctionApiKeyInput) }
                    }
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Amber.faint)
                    .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
                    .colorScheme(.dark)
                    Button(action: { showCorrectionApiKey.toggle() }) {
                        Text(showCorrectionApiKey ? "[HIDE]" : "[SHOW]")
                            .font(.amber(11))
                            .foregroundColor(Amber.dim)
                    }.buttonStyle(.plain)
                    Button(t(.correctionSave).uppercased()) { saveCorrectionApiKey() }
                        .font(.amber(11, weight: .bold))
                        .foregroundColor(Amber.primary)
                        .buttonStyle(.plain)
                }
                if appState.correctionApiProvider == .groq {
                    Text(t(.correctionGroqHint))
                        .font(.amber(11))
                        .foregroundColor(Amber.faint)
                }
                Text(t(.correctionKeychainNote))
                    .font(.amber(11))
                    .foregroundColor(Amber.faint)
            }
        }
    }

    private var correctionPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("// \(t(.correctionPromptLabel).uppercased())")
                    .font(.amber(11, weight: .bold))
                    .foregroundColor(Amber.dim)
                AmberInfoButton(text: t(.correctionPromptInfoHint))
                Spacer()
                Button(t(.correctionPromptReset).uppercased()) { appState.correctionPrompt = defaultCorrectionPrompt }
                    .font(.amber(11))
                    .foregroundColor(Amber.dim)
                    .buttonStyle(.plain)
            }
            TextEditor(text: $appState.correctionPrompt)
                .font(.amber(13))
                .foregroundColor(Amber.primary)
                .scrollContentBackground(.hidden)
                .background(Amber.faint)
                .frame(minHeight: 90)
                .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
        }
    }

    private func loadCorrectionApiKey() {
        correctionApiKeyInput = KeychainHelper.load(key: appState.correctionApiProvider.keychainKey) ?? ""
    }
    private func saveCorrectionApiKey() {
        if correctionApiKeyInput.isEmpty { KeychainHelper.delete(key: appState.correctionApiProvider.keychainKey) }
        else { KeychainHelper.save(key: appState.correctionApiProvider.keychainKey, value: correctionApiKeyInput) }
    }

    // MARK: Interface

    @ObservedObject private var updater = UpdateChecker.shared

    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.interfaceTitle), info: SettingsSection.interface_.info)

            // Interface language
            HStack {
                Text(t(.interfaceLanguageLabel).uppercased())
                    .font(.amber(13))
                    .foregroundColor(Amber.dim)
                Spacer()
                Picker("", selection: Binding(
                    get: { L10nState.shared.language },
                    set: { L10nState.shared.language = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 160)
                .colorScheme(.dark)
            }

            AmberDivider()

            // Version + update check
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(t(.updateCurrentVersion).uppercased()) \(appVersion)")
                        .font(.amber(13))
                        .foregroundColor(Amber.primary)
                    updateStatusLabel
                }
                Spacer()
                updateActionButton
            }
        }
    }

    @ViewBuilder
    private var updateStatusLabel: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            Text(t(.updateChecking).uppercased())
                .font(.amber(11))
                .foregroundColor(Amber.dim)
        case .upToDate:
            Text(t(.updateUpToDate).uppercased())
                .font(.amber(11))
                .foregroundColor(Amber.ok)
        case .available(let version, _):
            Text("\(t(.updateAvailable).uppercased()): V\(version)")
                .font(.amber(11))
                .foregroundColor(Amber.warn)
        case .error(let msg):
            Text("\(t(.updateError).uppercased()): \(msg)")
                .font(.amber(11))
                .foregroundColor(Amber.rec)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var updateActionButton: some View {
        switch updater.state {
        case .checking:
            Text("......")
                .font(.amber(12))
                .foregroundColor(Amber.hot)
                .frame(width: 80)
        case .available(_, let url):
            Button(t(.updateDownload).uppercased()) {
                updater.openReleasePage(url: url)
            }
            .font(.amber(12))
            .foregroundColor(Amber.bright)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Rectangle().stroke(Amber.hot, lineWidth: 1))
            .buttonStyle(.plain)
        default:
            Button(t(.updateCheck).uppercased()) {
                updater.check()
            }
            .font(.amber(12))
            .foregroundColor(Amber.dim)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Rectangle().stroke(Amber.border, lineWidth: 1))
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func providerTab(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.amber(12, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? Amber.bright : Amber.dim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Amber.faint : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AmberInfoButton

struct AmberInfoButton: View {
    let text: String
    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Text("[?]")
                .font(.amber(11))
                .foregroundColor(Amber.faint)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            ZStack {
                Amber.bg
                Text(text)
                    .font(.amber(13))
                    .foregroundColor(Amber.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: 260)
            }
        }
    }
}

// MARK: - InfoButton (legacy alias)

struct InfoButton: View {
    let text: String
    @State private var showPopover = false

    var body: some View {
        AmberInfoButton(text: text)
    }
}
