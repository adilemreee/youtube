//
//  ContentView.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .dashboard
    @Environment(DownloadManager.self) private var downloadManager
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .downloads:
            ActiveDownloadsView()
        case .history:
            HistoryView()
        case .playlists:
            PlaylistView()
        case .compressor:
            CompressorView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environment(DownloadManager())
        .modelContainer(for: DownloadItem.self)
}
