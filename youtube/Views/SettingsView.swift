//
//  SettingsView.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var ytdlpAvailable: Bool?
    @State private var ffmpegAvailable: Bool?
    @State private var launchAtLogin: Bool = false
    @State private var selectedLanguage: String = "system"
    
    private let shell = ShellRunner()
    
    private let availableLanguages = [
        ("system", "Sistem / System"),
        ("en", "English"),
        ("tr", "Türkçe")
    ]
    
    var body: some View {
        Form {
            // General Section
            Section("Genel / General") {
                // Download Path
                LabeledContent("İndirme Konumu / Download Location") {
                    HStack {
                        Text(settings.downloadPath.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        
                        Button("Değiştir... / Change...") {
                            selectDownloadPath()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Default Format
                Picker("Varsayılan Format / Default Format", selection: Binding(
                    get: { FormatOption(rawValue: settings.preferredFormat) ?? .mp4 },
                    set: { settings.preferredFormat = $0.rawValue }
                )) {
                    ForEach(FormatOption.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                
                // Default Quality
                Picker("Varsayılan Kalite / Default Quality", selection: Binding(
                    get: { QualityOption(rawValue: settings.preferredQuality) ?? .q1080p },
                    set: { settings.preferredQuality = $0.rawValue }
                )) {
                    ForEach(QualityOption.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }
            
            // Appearance Section
            Section("Görünüm / Appearance") {
                Picker("Tema / Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                Toggle("Menü Çubuğunda Göster / Show in Menu Bar", isOn: $settings.showInMenuBar)
                
                Toggle("Oturum Açıldığında Başlat / Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
                
                // Language Picker
                Picker("Dil / Language", selection: $selectedLanguage) {
                    ForEach(availableLanguages, id: \.0) { lang in
                        Text(lang.1).tag(lang.0)
                    }
                }
                .onChange(of: selectedLanguage) { _, newValue in
                    UserDefaults.standard.set([newValue == "system" ? nil : newValue].compactMap { $0 }, forKey: "AppleLanguages")
                }
            }
            
            // Dependencies Section
            Section("Bağımlılıklar / Dependencies") {
                dependencyRow(
                    name: "yt-dlp",
                    description: "Video indirme motoru / Video downloading engine",
                    isAvailable: ytdlpAvailable,
                    installCommand: "brew install yt-dlp"
                )
                
                dependencyRow(
                    name: "FFmpeg",
                    description: "Medya dönüştürme aracı / Media conversion tool",
                    isAvailable: ffmpegAvailable,
                    installCommand: "brew install ffmpeg"
                )
            }
            
            // About Section
            Section("Hakkında / About") {
                LabeledContent("Geliştirici / Developer", value: "Adil Emre Karayürek")
                LabeledContent("Sürüm / Version", value: "1.0.0")
                LabeledContent("Derleme / Build", value: "1")
                
                Link("GitHub'da Görüntüle / View on GitHub", destination: URL(string: "https://github.com/adilemreee/youtube.git")!)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .task {
            await checkDependencies()
            checkLaunchAtLoginStatus()
            loadLanguagePreference()
        }
    }
    
    // MARK: - Dependency Row
    
    private func dependencyRow(
        name: String,
        description: String,
        isAvailable: Bool?,
        installCommand: String
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let available = isAvailable {
                if available {
                    Label("Yüklü / Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Bulunamadı / Not Found", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        
                        Text(installCommand)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectDownloadPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "İndirme konumunu seçin / Select Download Location"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadPath = url
        }
    }
    
    private func checkDependencies() async {
        ytdlpAvailable = shell.findBinary("yt-dlp") != nil
        ffmpegAvailable = shell.findBinary("ffmpeg") != nil
    }
    
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set launch at login: \(error)")
            }
        }
    }
    
    private func loadLanguagePreference() {
        if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = languages.first {
            selectedLanguage = first
        } else {
            selectedLanguage = "system"
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
