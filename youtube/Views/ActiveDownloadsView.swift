//
//  ActiveDownloadsView.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI

struct ActiveDownloadsView: View {
    @Environment(DownloadManager.self) private var downloadManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            if downloadManager.activeDownloads.isEmpty {
                emptyState
            } else {
                downloadsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Active Downloads")
                    .font(.title.bold())
                
                Text("\(downloadManager.activeDownloads.count) item(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !downloadManager.completedDownloads.isEmpty {
                Button("Clear Completed") {
                    downloadManager.clearCompleted()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Active Downloads")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Start a download from the Dashboard")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Downloads List
    
    private var downloadsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(downloadManager.activeDownloads) { download in
                    DownloadItemRow(download: download)
                }
            }
            .padding()
        }
    }
}

// MARK: - Download Item Row

struct DownloadItemRow: View {
    @Bindable var download: ActiveDownload
    @Environment(DownloadManager.self) private var downloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Status
            HStack {
                Image(systemName: download.status.systemImage)
                    .foregroundStyle(statusColor)
                
                Text(download.title.isEmpty ? "Downloading..." : download.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(download.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            
            // Progress
            if download.status == .downloading {
                VStack(spacing: 6) {
                    GlassProgressBar(progress: download.progress)
                    
                    HStack {
                        Text("\(Int(download.progress * 100))%")
                            .font(.caption.monospacedDigit())
                        
                        Spacer()
                        
                        if !download.speed.isEmpty {
                            Text(download.speed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !download.eta.isEmpty {
                            Text("ETA: \(download.eta)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Error
            if let error = download.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Controls
            HStack {
                Text(download.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                if download.status.isActive {
                    Button {
                        downloadManager.cancelDownload(download)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
        .cardStyle()
    }
    
    private var statusColor: Color {
        switch download.status {
        case .pending, .fetching: return .orange
        case .downloading: return .blue
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

#Preview {
    ActiveDownloadsView()
        .environment(DownloadManager())
        .frame(width: 600, height: 500)
}
