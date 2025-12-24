//
//  SidebarView.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import SwiftUI

/// Navigation items for the sidebar
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case downloads = "Downloads"
    case history = "History"
    case playlists = "Playlists"
    case compressor = "Compressor"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .history: return "clock.arrow.circlepath"
        case .playlists: return "list.bullet"
        case .compressor: return "arrow.down.right.and.arrow.up.left"
        case .settings: return "gear"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Environment(DownloadManager.self) private var downloadManager
    
    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                    NavigationLink(value: item) {
                        Label {
                            Text(item.rawValue)
                        } icon: {
                            Image(systemName: item.icon)
                                .foregroundStyle(iconColor(for: item))
                        }
                        .badge(badgeCount(for: item))
                    }
                }
            } header: {
                Text("Menu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                NavigationLink(value: SidebarItem.settings) {
                    Label {
                        Text("Settings")
                    } icon: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
    
    private func iconColor(for item: SidebarItem) -> Color {
        switch item {
        case .dashboard: return .red
        case .downloads: return .blue
        case .history: return .orange
        case .playlists: return .purple
        case .compressor: return .green
        case .settings: return .gray
        }
    }
    
    private func badgeCount(for item: SidebarItem) -> Int {
        switch item {
        case .downloads:
            return downloadManager.activeDownloads.filter { $0.status.isActive }.count
        default:
            return 0
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
        .environment(DownloadManager())
        .frame(width: 220)
}
