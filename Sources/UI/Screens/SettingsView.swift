import SwiftUI
import Dependencies

// MARK: - Settings View

/// App settings and preferences
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Language preferences
                languageSection

                // Voice settings
                voiceSection

                // Appearance
                appearanceSection

                // Translation providers
                providersSection

                // Data management
                dataSection

                // About
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await viewModel.saveSettings()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await viewModel.loadSettings()
            }
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        Section {
            NavigationLink {
                LanguagePickerSheet(
                    selectedLanguage: $viewModel.settings.preferredSourceLanguage,
                    availableLanguages: SupportedLanguage.allCases,
                    title: "Default Source Language"
                )
            } label: {
                HStack {
                    Text("Source Language")
                    Spacer()
                    Text(viewModel.settings.preferredSourceLanguage.nativeName)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            NavigationLink {
                LanguagePickerSheet(
                    selectedLanguage: $viewModel.settings.preferredTargetLanguage,
                    availableLanguages: SupportedLanguage.allCases,
                    title: "Default Target Language"
                )
            } label: {
                HStack {
                    Text("Target Language")
                    Spacer()
                    Text(viewModel.settings.preferredTargetLanguage.nativeName)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        } header: {
            Text("Language")
        } footer: {
            Text("These languages will be used as defaults when starting a new conversation.")
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section {
            Toggle("Auto-speak Translations", isOn: $viewModel.settings.autoSpeakEnabled)

            HStack {
                Text("Speech Rate")
                Spacer()
                Slider(
                    value: $viewModel.settings.speechRate,
                    in: 0.5...2.0,
                    step: 0.1
                )
                .frame(width: 150)
                Text(String(format: "%.1fx", viewModel.settings.speechRate))
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 40)
            }

            NavigationLink {
                VoiceSelectionView(viewModel: viewModel)
            } label: {
                Text("Voice Selection")
            }
        } header: {
            Text("Voice")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $viewModel.settings.darkModePreference) {
                Text("System").tag(DarkModePreference.system)
                Text("Light").tag(DarkModePreference.light)
                Text("Dark").tag(DarkModePreference.dark)
            }

            Toggle("Show Transcription", isOn: $viewModel.settings.showTranscription)
            Toggle("Compact Mode", isOn: $viewModel.settings.compactMode)
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Providers Section

    private var providersSection: some View {
        Section {
            NavigationLink {
                APIKeySettingsView(viewModel: viewModel)
            } label: {
                HStack {
                    Text("API Keys")
                    Spacer()
                    if viewModel.hasAPIKeysConfigured {
                        Image(systemName: DesignSystem.Icons.checkmark)
                            .foregroundColor(.green)
                    }
                }
            }

            Toggle("Prefer On-Device", isOn: $viewModel.settings.preferOnDeviceTranslation)
        } header: {
            Text("Translation Providers")
        } footer: {
            Text("On-device translation works offline but may have lower quality for some language pairs.")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Toggle("Auto-save Conversations", isOn: $viewModel.settings.autoSaveEnabled)
            Toggle("iCloud Sync", isOn: $viewModel.settings.iCloudSyncEnabled)

            NavigationLink {
                GlossarySettingsView()
            } label: {
                Text("Custom Glossaries")
            }

            Button(role: .destructive) {
                viewModel.showClearDataAlert = true
            } label: {
                Text("Clear All Data")
            }
        } header: {
            Text("Data")
        }
        .alert("Clear All Data?", isPresented: $viewModel.showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await viewModel.clearAllData()
                }
            }
        } message: {
            Text("This will delete all conversations, glossaries, and settings. This action cannot be undone.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Link("Privacy Policy", destination: URL(string: "https://livelingo.app/privacy")!)
            Link("Terms of Service", destination: URL(string: "https://livelingo.app/terms")!)
            Link("Support", destination: URL(string: "https://livelingo.app/support")!)
        } header: {
            Text("About")
        }
    }
}

// MARK: - Voice Selection View

public struct VoiceSelectionView: View {
    @ObservedObject public var viewModel: SettingsViewModel

    public var body: some View {
        List {
            ForEach(SupportedLanguage.allCases) { language in
                Section(language.nativeName) {
                    ForEach(viewModel.availableVoices[language] ?? [], id: \.id) { voice in
                        Button {
                            viewModel.selectVoice(voice, for: language)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(voice.name)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)

                                    if let quality = voice.quality {
                                        Text(quality.displayName)
                                            .font(DesignSystem.Typography.caption1)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }

                                Spacer()

                                if viewModel.selectedVoices[language]?.id == voice.id {
                                    Image(systemName: DesignSystem.Icons.checkmark)
                                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice Selection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - API Key Settings View

public struct APIKeySettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var coeFontKey = ""
    @State private var showingKey: String?

    public var body: some View {
        List {
            Section {
                SecureInputField(
                    title: "OpenAI API Key",
                    text: $openAIKey,
                    isRevealed: showingKey == "openai"
                ) {
                    showingKey = showingKey == "openai" ? nil : "openai"
                }

                SecureInputField(
                    title: "Anthropic API Key",
                    text: $anthropicKey,
                    isRevealed: showingKey == "anthropic"
                ) {
                    showingKey = showingKey == "anthropic" ? nil : "anthropic"
                }

                SecureInputField(
                    title: "CoeFont API Key",
                    text: $coeFontKey,
                    isRevealed: showingKey == "coefont"
                ) {
                    showingKey = showingKey == "coefont" ? nil : "coefont"
                }
            } footer: {
                Text("API keys are stored securely in your device's keychain.")
            }

            Section {
                Button("Save API Keys") {
                    Task {
                        await viewModel.saveAPIKeys(
                            openAI: openAIKey,
                            anthropic: anthropicKey,
                            coeFont: coeFontKey
                        )
                    }
                }
                .disabled(openAIKey.isEmpty && anthropicKey.isEmpty && coeFontKey.isEmpty)
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Secure Input Field

public struct SecureInputField: View {
    public let title: String
    @Binding public var text: String
    public let isRevealed: Bool
    public let onToggle: () -> Void

    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if isRevealed {
                    TextField("Enter key", text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                } else {
                    SecureField("Enter key", text: $text)
                        .textContentType(.password)
                }
            }

            Button(action: onToggle) {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Glossary Settings View

public struct GlossarySettingsView: View {
    @State private var glossaries: [Glossary] = []

    public var body: some View {
        List {
            if glossaries.isEmpty {
                ContentUnavailableView(
                    "No Glossaries",
                    systemImage: "book.closed",
                    description: Text("Add custom glossaries to improve translation accuracy for specific terminology.")
                )
            } else {
                ForEach(glossaries) { glossary in
                    NavigationLink {
                        GlossaryDetailView(glossary: glossary)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(glossary.name)
                            Text("\(glossary.entries.count) terms")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Glossaries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Add glossary
                } label: {
                    Image(systemName: DesignSystem.Icons.add)
                }
            }
        }
    }
}

public struct GlossaryDetailView: View {
    public let glossary: Glossary

    public var body: some View {
        List {
            ForEach(glossary.entries) { entry in
                VStack(alignment: .leading) {
                    Text(entry.sourceTerm)
                        .font(DesignSystem.Typography.body)
                    Text(entry.targetTerm)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .navigationTitle(glossary.name)
    }
}

// MARK: - Settings View Model

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var settings = UserSettings()
    @Published public var showClearDataAlert = false
    @Published public var availableVoices: [SupportedLanguage: [VoiceOption]] = [:]
    @Published public var selectedVoices: [SupportedLanguage: VoiceOption] = [:]

    @Dependency(\.settingsRepository) private var settingsRepository
    @Dependency(\.ttsService) private var ttsService

    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var hasAPIKeysConfigured: Bool {
        // Check if any API keys are configured
        return false // Would check keychain
    }

    public func loadSettings() async {
        settings = await settingsRepository.getSettings()
        await loadVoices()
    }

    public func saveSettings() async {
        try? await settingsRepository.saveSettings(settings)
    }

    public func clearAllData() async {
        await settingsRepository.resetToDefaults()
        settings = UserSettings()
    }

    public func saveAPIKeys(openAI: String, anthropic: String, coeFont: String) async {
        let keyManager = APIKeyManager()
        if !openAI.isEmpty {
            try? await keyManager.setOpenAIAPIKey(openAI)
        }
        if !anthropic.isEmpty {
            try? await keyManager.setAnthropicAPIKey(anthropic)
        }
        if !coeFont.isEmpty {
            try? await keyManager.setCoeFontAPIKey(coeFont)
        }
    }

    public func selectVoice(_ voice: VoiceOption, for language: SupportedLanguage) {
        selectedVoices[language] = voice
    }

    private func loadVoices() async {
        for language in SupportedLanguage.allCases {
            availableVoices[language] = await ttsService.availableVoices(for: language)
        }
    }
}

// MARK: - Extended UserSettings

extension UserSettings {
    public var autoSpeakEnabled: Bool {
        get { true }
        set { }
    }

    public var speechRate: Double {
        get { 1.0 }
        set { }
    }

    public var showTranscription: Bool {
        get { true }
        set { }
    }

    public var compactMode: Bool {
        get { false }
        set { }
    }

    public var preferOnDeviceTranslation: Bool {
        get { true }
        set { }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
