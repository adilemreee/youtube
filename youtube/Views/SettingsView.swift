//
//  SettingsView.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var ytdlpAvailable: Bool?
    @State private var ffmpegAvailable: Bool?
    
    private let shell = ShellRunner()
    
    var body: some View {
        Form {
            // General Section
            Section("General") {
                // Download Path
                LabeledContent("Download Location") {
                    HStack {
                        Text(settings.downloadPath.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        
                        Button("Change...") {
                            selectDownloadPath()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Default Format
                Picker("Default Format", selection: Binding(
                    get: { FormatOption(rawValue: settings.preferredFormat) ?? .mp4 },
                    set: { settings.preferredFormat = $0.rawValue }
                )) {
                    ForEach(FormatOption.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                
                // Default Quality
                Picker("Default Quality", selection: Binding(
                    get: { QualityOption(rawValue: settings.preferredQuality) ?? .q1080p },
                    set: { settings.preferredQuality = $0.rawValue }
                )) {
                    ForEach(QualityOption.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }
            
            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
            }
            
            // Dependencies Section
            Section("Dependencies") {
                dependencyRow(
                    name: "yt-dlp",
                    description: "Video downloading engine",
                    isAvailable: ytdlpAvailable,
                    installCommand: "brew install yt-dlp"
                )
                
                dependencyRow(
                    name: "FFmpeg",
                    description: "Media conversion tool",
                    isAvailable: ffmpegAvailable,
                    installCommand: "brew install ffmpeg"
                )
            }
            
            // About Section
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
                
                Link("View on GitHub", destination: URL(string: "https://github.com")!)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .task {
            await checkDependencies()
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
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Not Found", systemImage: "xmark.circle.fill")
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
        panel.message = "Select Download Location"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadPath = url
        }
    }
    
    private func checkDependencies() async {
        ytdlpAvailable = await shell.findBinary("yt-dlp") != nil
        ffmpegAvailable = await shell.findBinary("ffmpeg") != nil
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
