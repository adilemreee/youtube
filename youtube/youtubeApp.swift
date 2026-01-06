//
//  youtubeApp.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI
import SwiftData

@main
struct youtubeApp: App {
    @State private var downloadManager = DownloadManager()
    @State private var settings = AppSettings.shared
    
    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environment(downloadManager)
                .preferredColorScheme(settings.theme.colorScheme)
        }
        .modelContainer(for: DownloadItem.self)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu("Downloads") {
                Button("Clear Terminal") {
                    downloadManager.terminalOutput = ""
                }
                .keyboardShortcut("K", modifiers: [.command])
                
                Button("Clear Completed") {
                    downloadManager.clearCompleted()
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
            }
        }
        
        // Menu Bar Extra
        MenuBarExtra("VidFlow", systemImage: "play.rectangle.fill") {
            MenuBarView()
                .environment(downloadManager)
        }
        .menuBarExtraStyle(.window)
        
        // Settings Window
        Settings {
            SettingsView()
        }
    }
}
