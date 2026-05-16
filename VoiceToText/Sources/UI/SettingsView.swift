import SwiftUI
import AppKit

// MARK: - Разделы настроек

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
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(minWidth: 130, alignment: .leading)
            Spacer()
            Button(action: toggleRecording) {
                Text(isRecording ? t(.hotkeyPressKey) : binding.displayString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isRecording ? .orange : .white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isRecording ? Color.orange.opacity(0.15) : Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecording ? Color.orange.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isRecording)
            Button(action: resetToDefault) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(binding == defaultBinding ? 0.15 : 0.4))
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))

            HStack(spacing: 0) {
                // Боковая навигация
                sidebarView
                    .frame(width: 150)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Контент раздела
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionContent(selectedSection)
                            .padding(24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 520)
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text(t(.settingsTitle))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.08))

            // Пункты меню
            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    sidebarItem(section)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()

            // Кнопка доната
            Button(action: onDonate) {
                HStack(spacing: 6) {
                    Text("🪙")
                        .font(.system(size: 12))
                    Text(t(.settingsSupportButton))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 14)
        }
    }

    private func sidebarItem(_ section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        return Button(action: { selectedSection = section }) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                    .frame(width: 16)
                Text(section.label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Заголовок раздела с ⓘ

    private func sectionTitle(_ title: String, info: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            InfoButton(text: info)
            Spacer()
        }
        .padding(.bottom, 16)
    }

    // MARK: - Контент разделов

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

    // MARK: Хоткеи

    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.sectionHotkeys), info: SettingsSection.hotkeys.info)
            HotkeyRecorderButton(label: t(.hotkeyPTT), isForPTT: true,  binding: $hotkeys.pttBinding)
            Divider().background(Color.white.opacity(0.06))
            HotkeyRecorderButton(label: t(.hotkeyVAD), isForPTT: false, binding: $hotkeys.vadBinding)
            Text(t(.hotkeyHint))
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
                .padding(.top, 4)
        }
    }

    // MARK: Модель

    @ObservedObject private var modelManager = ModelManager.shared
    @State private var downloadingModel: LocalWhisperModel? = nil
    @State private var downloadProgress: Double = 0
    @State private var downloadLabel: String = ""
    @State private var apiKeyInput: String = ""
    @State private var showApiKey: Bool = false

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.sectionModel), info: SettingsSection.model.info)

            HStack(spacing: 8) {
                providerTab(label: t(.modelLocal), isSelected: appState.transcriptionProvider == .local) {
                    appState.transcriptionProvider = .local
                }
                providerTab(label: t(.modelCloud), isSelected: appState.transcriptionProvider == .cloud) {
                    appState.transcriptionProvider = .cloud
                }
            }

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
        VStack(spacing: 6) {
            ForEach(LocalWhisperModel.allCases) { model in
                localModelRow(model)
            }
            if downloadingModel != nil {
                VStack(spacing: 4) {
                    HStack {
                        Text(downloadLabel)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    ProgressView(value: downloadProgress).tint(.blue)
                }
                .padding(.top, 4)
            }
        }
    }

    private func localModelRow(_ model: LocalWhisperModel) -> some View {
        let status = modelManager.modelStatuses[model] ?? .notDownloaded
        let isSelected = appState.transcriptionProvider == .local && appState.selectedLocalModel == model
        let isDownloaded = status == .downloaded
        let isDownloading = downloadingModel == model

        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(isSelected ? Color.blue : Color.white.opacity(0.06)).frame(width: 18, height: 18)
                if isSelected { Circle().fill(.white).frame(width: 7, height: 7) }
            }
            .onTapGesture { if isDownloaded && !isDownloading { appState.switchLocalModel(to: model) } }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(isDownloaded ? .white.opacity(0.85) : .white.opacity(0.35))
                    if appState.isModelSwitching && isSelected {
                        Text(t(.modelLoading))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                }
                Text(model.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
            }
            Spacer()
            if isDownloading {
                ProgressView().scaleEffect(0.6).frame(width: 60)
            } else if isDownloaded {
                if isSelected {
                    Text(t(.modelActive))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.green.opacity(0.7))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green.opacity(0.1)).cornerRadius(6)
                } else {
                    Button(t(.modelSelect)) { appState.switchLocalModel(to: model) }
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.blue.opacity(0.8)).buttonStyle(.plain)
                }
            } else {
                Button(t(.modelDownload)) { startDownload(model) }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.07)).cornerRadius(6).buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1))
        )
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
            VStack(spacing: 6) {
                ForEach(CloudProvider.allCases) { provider in cloudProviderRow(provider) }
            }
            Divider().background(Color.white.opacity(0.06))
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t(.modelApiKeyFor)) \(appState.selectedCloudProvider.displayName)")
                    .font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.4))
                HStack(spacing: 8) {
                    Group {
                        if showApiKey { TextField("sk-...", text: $apiKeyInput) }
                        else { SecureField("sk-...", text: $apiKeyInput) }
                    }
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                    .textFieldStyle(.plain).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.05)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .colorScheme(.dark)
                    Button(action: { showApiKey.toggle() }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.35))
                    }.buttonStyle(.plain)
                    Button(t(.modelSave)) { saveApiKey() }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.blue.opacity(0.8)).buttonStyle(.plain)
                }
                Text(t(.modelKeychainNote))
                    .font(.system(size: 10, design: .rounded)).foregroundColor(.white.opacity(0.2))
            }
        }
    }

    private func cloudProviderRow(_ provider: CloudProvider) -> some View {
        let isSelected = appState.selectedCloudProvider == provider
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(isSelected ? Color.blue : Color.white.opacity(0.06)).frame(width: 18, height: 18)
                if isSelected { Circle().fill(.white).frame(width: 7, height: 7) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName).font(.system(size: 13, design: .rounded)).foregroundColor(.white.opacity(0.85))
                Text(provider.description).font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.3))
            }
            Spacer()
            if KeychainHelper.load(key: provider.keychainKey) != nil {
                Text(t(.modelKeySet)).font(.system(size: 10, design: .rounded)).foregroundColor(.green.opacity(0.6))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.blue.opacity(0.08) : Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)))
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

    // MARK: Язык

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.langTitle), info: SettingsSection.language.info)
            HStack {
                Text(t(.interfaceLanguageLabel))
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $appState.transcriptionLanguage) {
                    ForEach(WhisperLanguage.all) { lang in Text(lang.name).tag(lang.id) }
                }
                .pickerStyle(.menu).frame(maxWidth: 220).colorScheme(.dark)
            }
            Text(t(.langHint))
                .font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.25))
        }
    }

    // MARK: Промт Whisper

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(t(.promptTitle), info: SettingsSection.prompt.info)
                Spacer()
                Toggle("", isOn: $appState.promptEnabled)
                    .toggleStyle(.switch).scaleEffect(0.8).tint(.blue)
            }
            if appState.promptEnabled {
                TextEditor(text: $appState.transcriptionPrompt)
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                    .scrollContentBackground(.hidden).background(Color.white.opacity(0.05))
                    .cornerRadius(8).frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                HStack {
                    Spacer()
                    Button(t(.promptReset)) {
                        appState.transcriptionPrompt = t(.promptDefaultText)
                    }
                    .font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.35)).buttonStyle(.plain)
                }
            } else {
                Text(t(.promptDisabledHint))
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.white.opacity(0.25))
            }
        }
    }

    // MARK: Коррекция

    @ObservedObject private var ollamaManager = OllamaManager.shared
    @State private var correctionApiKeyInput: String = ""
    @State private var showCorrectionApiKey: Bool = false

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(t(.correctionTitle), info: SettingsSection.correction.info)

            // Выбор режима
            VStack(spacing: 6) {
                correctionModeRow(.off)
                correctionModeRow(.ollama)
                correctionModeRow(.api)
            }

            if appState.correctionMode != .off {
                Divider().background(Color.white.opacity(0.08))
            }

            // Ollama настройки
            if appState.correctionMode == .ollama {
                ollamaCorrectionSection
            }

            // API настройки
            if appState.correctionMode == .api {
                apiCorrectionSection
            }

            // Поле промта
            if appState.correctionMode != .off {
                Divider().background(Color.white.opacity(0.08))
                correctionPromptSection
            }
        }
        .onAppear { loadCorrectionApiKey() }
        .onChange(of: appState.correctionApiProvider) { _ in loadCorrectionApiKey() }
    }

    private func correctionModeRow(_ mode: CorrectionMode) -> some View {
        let isSelected = appState.correctionMode == mode
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(isSelected ? Color.blue : Color.white.opacity(0.06)).frame(width: 18, height: 18)
                if isSelected { Circle().fill(.white).frame(width: 7, height: 7) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.white.opacity(0.85))
                Text(correctionModeDescription(mode))
                    .font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.3))
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.blue.opacity(0.08) : Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)))
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

            // Статус установки + ползунок
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Ollama")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                        Text("• \(ollamaStatusLabel)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ollamaStatusColor)
                    }
                    Text("\(t(.correctionOllamaModelLabel)) \(OllamaManager.defaultModel) (~1.3 ГБ)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
                Spacer()

                // Ползунок включения (только если установлена)
                if ollamaManager.isInstalled {
                    Toggle("", isOn: $ollamaManager.enabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.85)
                        .tint(.blue)
                        .disabled(isOllamaToggleDisabled)
                }
            }

            // Кнопка установки / прогресс
            switch ollamaManager.installStatus {
            case .notInstalled:
                Button(action: { Task { await ollamaManager.install() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 13))
                        Text(t(.correctionInstallOllama))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(9)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.blue.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)

            case .installing(let progress, let label):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(label)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    ProgressView(value: progress).tint(.blue)
                }

            case .installed:
                // Прогресс скачивания модели
                switch ollamaManager.modelStatus {
                case .notPulled:
                    if case .running = ollamaManager.serverStatus {
                        Button(action: { Task { await ollamaManager.pullModel() } }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 13))
                                Text("\(t(.correctionDownloadModel)) (\(OllamaManager.defaultModel))")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(9)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.blue.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                case .pulling(let progress):
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t(.correctionLoadingModel))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        ProgressView(value: progress).tint(.blue)
                    }
                case .ready:
                    EmptyView()
                case .error(let msg):
                    Text(t(.correctionModelError) + msg)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.red.opacity(0.7))
                }

            case .error(let msg):
                Text(t(.correctionInstallError) + msg)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.red.opacity(0.7))
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

    private var ollamaStatusColor: Color {
        switch ollamaManager.installStatus {
        case .notInstalled: return .white.opacity(0.3)
        case .installing:   return .orange.opacity(0.7)
        case .error:        return .red.opacity(0.7)
        case .installed:
            if case .running = ollamaManager.serverStatus,
               case .ready = ollamaManager.modelStatus { return .green.opacity(0.7) }
            if case .stopped = ollamaManager.serverStatus { return .white.opacity(0.3) }
            if case .error = ollamaManager.serverStatus { return .red.opacity(0.7) }
            return .orange.opacity(0.7)
        }
    }

    private var isOllamaToggleDisabled: Bool {
        switch ollamaManager.serverStatus {
        case .starting, .stopping: return true
        default: return false
        }
    }

    private var apiCorrectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Выбор провайдера
            HStack(spacing: 8) {
                ForEach(CorrectionApiProvider.allCases) { provider in
                    Button(action: { appState.correctionApiProvider = provider }) {
                        Text(provider.displayName)
                            .font(.system(size: 11, weight: appState.correctionApiProvider == provider ? .semibold : .regular, design: .rounded))
                            .foregroundColor(appState.correctionApiProvider == provider ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7)
                                .fill(appState.correctionApiProvider == provider ? Color.blue.opacity(0.25) : Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .stroke(appState.correctionApiProvider == provider ? Color.blue.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)))
                    }.buttonStyle(.plain)
                }
            }

            // Эндпоинт для кастомного провайдера
            if appState.correctionApiProvider == .custom {
                TextField("https://...", text: $appState.correctionCustomEndpoint)
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                    .textFieldStyle(.plain).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.05)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .colorScheme(.dark)
            }

            // API-ключ
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t(.correctionApiKeyLabel)) (\(appState.correctionApiProvider.displayName))")
                    .font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.4))
                HStack(spacing: 8) {
                    Group {
                        if showCorrectionApiKey { TextField("sk-...", text: $correctionApiKeyInput) }
                        else { SecureField("sk-...", text: $correctionApiKeyInput) }
                    }
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                    .textFieldStyle(.plain).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.05)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .colorScheme(.dark)
                    Button(action: { showCorrectionApiKey.toggle() }) {
                        Image(systemName: showCorrectionApiKey ? "eye.slash" : "eye")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.35))
                    }.buttonStyle(.plain)
                    Button(t(.correctionSave)) { saveCorrectionApiKey() }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.blue.opacity(0.8)).buttonStyle(.plain)
                }
                if appState.correctionApiProvider == .groq {
                    Text(t(.correctionGroqHint))
                        .font(.system(size: 10, design: .rounded)).foregroundColor(.white.opacity(0.2))
                }
                Text(t(.correctionKeychainNote))
                    .font(.system(size: 10, design: .rounded)).foregroundColor(.white.opacity(0.2))
            }
        }
    }

    private var correctionPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t(.correctionPromptLabel))
                    .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.3))
                InfoButton(text: t(.correctionPromptInfoHint))
                Spacer()
                Button(t(.correctionPromptReset)) { appState.correctionPrompt = defaultCorrectionPrompt }
                    .font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.35)).buttonStyle(.plain)
            }
            TextEditor(text: $appState.correctionPrompt)
                .font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.75))
                .scrollContentBackground(.hidden).background(Color.white.opacity(0.04))
                .cornerRadius(8).frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func loadCorrectionApiKey() {
        correctionApiKeyInput = KeychainHelper.load(key: appState.correctionApiProvider.keychainKey) ?? ""
    }
    private func saveCorrectionApiKey() {
        if correctionApiKeyInput.isEmpty { KeychainHelper.delete(key: appState.correctionApiProvider.keychainKey) }
        else { KeychainHelper.save(key: appState.correctionApiProvider.keychainKey, value: correctionApiKeyInput) }
    }

    // MARK: Интерфейс

    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(t(.interfaceTitle), info: SettingsSection.interface_.info)
            HStack {
                Text(t(.interfaceLanguageLabel))
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: Binding(
                    get: { L10nState.shared.language },
                    set: { L10nState.shared.language = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu).frame(maxWidth: 160).colorScheme(.dark)
            }
        }
    }

    // MARK: - Helpers

    private func providerTab(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.25) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)))
        }.buttonStyle(.plain)
    }
}

// MARK: - InfoButton

struct InfoButton: View {
    let text: String
    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.25))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: 260)
                .background(Color.black.opacity(0.9))
        }
    }
}
