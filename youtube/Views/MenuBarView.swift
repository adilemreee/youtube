//
//  MenuBarView.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.openWindow) private var openWindow
    
    private let clipboardManager = ClipboardManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Quick Download
            quickDownloadSection
            
            Divider()
            
            // Active Downloads
            if downloadManager.hasActiveDownloads {
                activeDownloadsSection
                Divider()
            }
            
            // Recent Downloads
            if !downloadManager.recentDownloads.isEmpty {
                recentDownloadsSection
                Divider()
            }
            
            // Footer Actions
            footerSection
        }
        .frame(width: 300)
        .onAppear {
            clipboardManager.updateFromClipboard()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("VidFlow")
                    .font(.headline)
                
                if downloadManager.hasActiveDownloads {
                    Text("\(downloadManager.activeDownloads.filter { $0.status.isActive }.count) active download(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Quick Download Section
    
    private var quickDownloadSection: some View {
        VStack(spacing: 8) {
            if clipboardManager.hasValidURL {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                    
                    Text(clipboardManager.getPlatformName(from: clipboardManager.detectedURL ?? ""))
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button("Download") {
                        if let url = clipboardManager.detectedURL {
                            Task {
                                await downloadManager.startDownload(
                                    url: url,
                                    format: downloadManager.preferredFormat,
                                    quality: downloadManager.preferredQuality
                                )
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Text(clipboardManager.detectedURL ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                HStack {
                    Image(systemName: "clipboard")
                        .foregroundStyle(.secondary)
                    
                    Text("No video URL in clipboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        clipboardManager.updateFromClipboard()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Active Downloads Section
    
    private var activeDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Downloads")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(downloadManager.activeDownloads.filter { $0.status.isActive }.prefix(2)) { download in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(download.title.isEmpty ? "Downloading..." : download.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        GlassProgressBar(progress: download.progress, height: 4)
                    }
                    
                    Text("\(Int(download.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Recent Downloads Section
    
    private var recentDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(downloadManager.recentDownloads.filter { $0.status == .completed }.prefix(3)) { download in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    
                    Text(download.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
        }
        .padding()
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            Button {
                openWindow(id: "main")
            } label: {
                Label("Open App", systemImage: "macwindow")
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .padding()
    }
}

#Preview {
    MenuBarView()
        .environment(DownloadManager())
        .frame(width: 300)
}
