//
//  DashboardView.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.modelContext) private var modelContext
    @State private var urlInput: String = ""
    @State private var selectedFormat: FormatOption = .mp4
    @State private var selectedQuality: QualityOption = .q1080p
    @State private var showTerminal: Bool = true
    
    private let clipboardManager = ClipboardManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // URL Input
                urlInputSection
                
                // Video Preview (if info fetched)
                if let videoInfo = downloadManager.currentVideoInfo {
                    videoPreviewCard(videoInfo)
                }
                
                // Format & Quality Selection
                formatSelectionSection
                
                // Download Button
                downloadButton
                
                // Terminal Output
                if showTerminal {
                    terminalSection
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            clipboardManager.updateFromClipboard()
            if let url = clipboardManager.detectedURL, urlInput.isEmpty {
                urlInput = url
            }
            // Request notification permission
            downloadManager.requestNotificationPermission()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading) {
                    Text("YouTube Downloader")
                        .font(.title.bold())
                    Text("Download videos from YouTube and other platforms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - URL Input Section
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video URL")
                .font(.headline)
            
            HStack(spacing: 12) {
                TextField("Paste video URL here...", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                
                Button {
                    clipboardManager.updateFromClipboard()
                    if let url = clipboardManager.detectedURL {
                        urlInput = url
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .help("Paste from clipboard")
                
                Button {
                    guard !urlInput.isEmpty else { return }
                    Task {
                        await downloadManager.fetchVideoInfo(url: urlInput)
                    }
                } label: {
                    if downloadManager.isFetching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlInput.isEmpty || downloadManager.isFetching)
                .help("Fetch video info")
            }
            
            if let error = downloadManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Video Preview Card
    
    private func videoPreviewCard(_ info: VideoInfo) -> some View {
        HStack(spacing: 16) {
            // Thumbnail with async loading
            if let thumbnailURL = info.thumbnail, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 160, height: 90)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 160, height: 90)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 90)
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.8))
                    }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(info.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let uploader = info.uploader ?? info.channel {
                    Text(uploader)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label(info.durationFormatted, systemImage: "clock")
                    
                    if let views = info.viewCount {
                        Label(formatViewCount(views), systemImage: "eye")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .cardStyle()
    }
    
    // MARK: - Format Selection Section
    
    private var formatSelectionSection: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.headline)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(FormatOption.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.headline)
                
                Picker("Quality", selection: $selectedQuality) {
                    ForEach(QualityOption.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .disabled(selectedFormat.isAudio)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Download Button
    
    private var downloadButton: some View {
        Button {
            downloadManager.addToQueue(
                url: urlInput,
                format: selectedFormat.rawValue,
                quality: selectedQuality.rawValue,
                modelContext: modelContext
            )
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                if downloadManager.queueCount > 0 {
                    Text("Add to Queue (\(downloadManager.queueCount))")
                } else {
                    Text("Download")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(urlInput.isEmpty)
    }
    
    // MARK: - Terminal Section
    
    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showTerminal.toggle()
                } label: {
                    Image(systemName: showTerminal ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.plain)
                
                Button {
                    downloadManager.terminalOutput = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(downloadManager.terminalOutput.isEmpty)
            }
            
            if showTerminal {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(downloadManager.terminalOutput.isEmpty ? "Ready..." : downloadManager.terminalOutput)
                            .id("terminal-bottom")
                    }
                    .terminalStyle()
                    .frame(height: 200)
                    .onChange(of: downloadManager.terminalOutput) { _, _ in
                        proxy.scrollTo("terminal-bottom", anchor: .bottom)
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Helpers
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

#Preview {
    DashboardView()
        .environment(DownloadManager())
        .frame(width: 800, height: 700)
}
