//
//  HistoryView.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI
import SwiftData
import AVFoundation
import AppKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadItem.dateCreated, order: .reverse) private var items: [DownloadItem]
    @State private var searchText: String = ""
    @State private var hoveredItem: UUID?
    
    var filteredItems: [DownloadItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
            item.url.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Search bar
            searchBar
            
            if items.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Download History")
                    .font(.title.bold())
                
                Text("\(items.count) video\(items.count == 1 ? "" : "s") downloaded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !items.isEmpty {
                Button(role: .destructive) {
                    clearHistory()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search downloads...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Download History")
                    .font(.title2.bold())
                
                Text("Your downloaded videos will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredItems) { item in
                    HistoryItemRow(
                        item: item,
                        isHovered: hoveredItem == item.id,
                        onDelete: { deleteItem(item) }
                    )
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item.id : nil
                    }
                    .contextMenu {
                        contextMenuItems(for: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuItems(for item: DownloadItem) -> some View {
        Button {
            openInFinder(item)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        
        Button {
            playFile(item)
        } label: {
            Label("Play", systemImage: "play.fill")
        }
        
        Button {
            copyURL(item)
        } label: {
            Label("Copy URL", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            deleteItem(item)
        } label: {
            Label("Delete from History", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func openInFinder(_ item: DownloadItem) {
        let url = URL(fileURLWithPath: item.filePath)
        if FileManager.default.fileExists(atPath: item.filePath) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    private func playFile(_ item: DownloadItem) {
        let url = URL(fileURLWithPath: item.filePath)
        if FileManager.default.fileExists(atPath: item.filePath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func copyURL(_ item: DownloadItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url, forType: .string)
    }
    
    private func deleteItem(_ item: DownloadItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            modelContext.delete(item)
        }
    }
    
    private func clearHistory() {
        withAnimation {
            for item in items {
                modelContext.delete(item)
            }
        }
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: DownloadItem
    let isHovered: Bool
    let onDelete: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var fileExists: Bool = true
    
    private var formatColor: Color {
        switch item.format.lowercased() {
        case "mp4": return .blue
        case "webm": return .green
        case "mp3": return .pink
        case "m4a": return .orange
        default: return .gray
        }
    }
    
    private var isAudio: Bool {
        ["mp3", "m4a", "aac", "wav"].contains(item.format.lowercased())
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            thumbnailView
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(cleanTitle(item.title))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(fileExists ? .primary : .secondary)
                
                HStack(spacing: 16) {
                    // Format tag
                    Text(item.format.uppercased())
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(formatColor.opacity(0.15))
                        .foregroundStyle(formatColor)
                        .clipShape(Capsule())
                    
                    // Quality
                    if !isAudio {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(item.quality)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    // File size
                    if item.fileSize > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "doc")
                                .font(.caption2)
                            Text(formatFileSize(item.fileSize))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    // File missing indicator
                    if !fileExists {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("File not found")
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
            
            Spacer()
            
            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.dateCreated, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(item.dateCreated, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Quick Actions
            HStack(spacing: 6) {
                Button {
                    playFile()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(fileExists ? .blue : .gray)
                .disabled(!fileExists)
                .help("Play")
                
                Button {
                    openInFinder()
                } label: {
                    Image(systemName: "folder.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(fileExists ? .orange : .gray)
                .disabled(!fileExists)
                .help("Show in Finder")
                
                if isHovered {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.8))
                    .help("Delete")
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHovered ? formatColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onAppear {
            checkFileExists()
            loadThumbnail()
        }
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [formatColor.opacity(0.6), formatColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 56)
                    .overlay {
                        Image(systemName: isAudio ? "music.note" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
            }
            
            // Play overlay on hover
            if isHovered && fileExists {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.4))
                    .frame(width: 80, height: 56)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
            }
        }
        .onTapGesture {
            if fileExists {
                playFile()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func checkFileExists() {
        fileExists = FileManager.default.fileExists(atPath: item.filePath)
    }
    
    private func loadThumbnail() {
        guard !isAudio else { return }
        
        let filePath = item.filePath
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        
        Task.detached(priority: .background) {
            let url = URL(fileURLWithPath: filePath)
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 160, height: 112)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 160, height: 112))
                
                await MainActor.run {
                    self.thumbnail = nsImage
                }
            } catch {
                // Silently fail - will show placeholder
            }
        }
    }
    
    private func playFile() {
        let url = URL(fileURLWithPath: item.filePath)
        NSWorkspace.shared.open(url)
    }
    
    private func openInFinder() {
        let url = URL(fileURLWithPath: item.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let extensions = [".mp4", ".webm", ".mp3", ".m4a", ".f251", ".f140", ".f137", ".f248", ".f299", ".f303"]
        for ext in extensions {
            cleaned = cleaned.replacingOccurrences(of: ext, with: "")
        }
        return cleaned.isEmpty ? "Unknown Video" : cleaned
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: DownloadItem.self)
        .frame(width: 700, height: 500)
}
