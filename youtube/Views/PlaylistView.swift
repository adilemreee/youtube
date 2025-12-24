//
//  PlaylistView.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import SwiftUI
import SwiftData

struct PlaylistView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(\.modelContext) private var modelContext
    @State private var playlistURL: String = ""
    @State private var selectedEntries: Set<String> = []
    @State private var selectedFormat: FormatOption = .mp4
    @State private var selectedQuality: QualityOption = .q1080p
    
    private var playlist: PlaylistInfo? {
        downloadManager.currentPlaylistInfo
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // URL Input
            urlInputSection
            
            if let playlist = playlist {
                // Playlist Info
                playlistInfoCard(playlist)
                
                // Selection Controls
                selectionControls
                
                // Entries List
                entriesList(playlist)
                
                // Download Button
                downloadButton
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Playlist Downloader")
                    .font(.title.bold())
                
                Text("Download entire playlists at once")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - URL Input
    
    private var urlInputSection: some View {
        HStack(spacing: 12) {
            TextField("Paste playlist URL...", text: $playlistURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            
            Button {
                Task {
                    selectedEntries.removeAll()
                    await downloadManager.fetchVideoInfo(url: playlistURL)
                    // Auto-select all
                    if let entries = playlist?.entries {
                        selectedEntries = Set(entries.map { $0.id })
                    }
                }
            } label: {
                if downloadManager.isFetching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Fetch Playlist")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(playlistURL.isEmpty || downloadManager.isFetching)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Playlist Info Card
    
    private func playlistInfoCard(_ playlist: PlaylistInfo) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.purple)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .font(.headline)
                
                if let uploader = playlist.uploader {
                    Text(uploader)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("\(playlist.entries.count) videos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .cardStyle()
        .padding(.horizontal)
    }
    
    // MARK: - Selection Controls
    
    private var selectionControls: some View {
        HStack {
            Button("Select All") {
                if let entries = playlist?.entries {
                    selectedEntries = Set(entries.map { $0.id })
                }
            }
            .buttonStyle(.bordered)
            
            Button("Deselect All") {
                selectedEntries.removeAll()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Text("\(selectedEntries.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Format", selection: $selectedFormat) {
                ForEach(FormatOption.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            Picker("Quality", selection: $selectedQuality) {
                ForEach(QualityOption.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding()
    }
    
    // MARK: - Entries List
    
    private func entriesList(_ playlist: PlaylistInfo) -> some View {
        List(playlist.entries, selection: $selectedEntries) { entry in
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: selectedEntries.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedEntries.contains(entry.id) ? .blue : .secondary)
                    .onTapGesture {
                        if selectedEntries.contains(entry.id) {
                            selectedEntries.remove(entry.id)
                        } else {
                            selectedEntries.insert(entry.id)
                        }
                    }
                
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 34)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title ?? "Unknown")
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Text(entry.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedEntries.contains(entry.id) {
                    selectedEntries.remove(entry.id)
                } else {
                    selectedEntries.insert(entry.id)
                }
            }
        }
        .listStyle(.inset)
    }
    
    // MARK: - Download Button
    
    private var downloadButton: some View {
        Button {
            Task {
                await downloadSelectedVideos()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Download \(selectedEntries.count) Video(s)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(selectedEntries.isEmpty)
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Enter a Playlist URL")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Paste a YouTube playlist URL above to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func downloadSelectedVideos() async {
        guard let entries = playlist?.entries else { return }
        
        let selected = entries.filter { selectedEntries.contains($0.id) }
        
        for entry in selected {
            if let url = entry.url {
                await downloadManager.startDownload(
                    url: url,
                    format: selectedFormat.rawValue,
                    quality: selectedQuality.rawValue,
                    modelContext: modelContext
                )
            }
        }
    }
}

#Preview {
    PlaylistView()
        .environment(DownloadManager())
        .modelContainer(for: DownloadItem.self)
        .frame(width: 700, height: 600)
}
