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
    private let historyStore = DownloadHistoryStore.shared
    
    var body: some Scene {
        let menuBarVisibility = Binding(
            get: { settings.showInMenuBar },
            set: { settings.showInMenuBar = $0 }
        )
        
        // Main Window
        WindowGroup(id: "main") {
            ContentView()
                .environment(downloadManager)
                .environment(historyStore)
                .preferredColorScheme(settings.theme.colorScheme)
        }
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
        MenuBarExtra("VidFlow", systemImage: "play.rectangle.fill", isInserted: menuBarVisibility) {
            MenuBarView()
                .environment(downloadManager)
                .environment(historyStore)
        }
        .menuBarExtraStyle(.window)
        
        // Settings Window
        Settings {
            SettingsView()
                .environment(historyStore)
        }
    }
}
