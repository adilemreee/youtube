//
//  AppSettings.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import Foundation
import SwiftUI

/// Centralized app settings using AppStorage
@Observable
class AppSettings {
    
    static let shared = AppSettings()
    
    // MARK: - Download Settings
    
    var downloadPath: URL {
        get {
            if let data = UserDefaults.standard.data(forKey: "downloadPath"),
               let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as URL? {
                return url
            }
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue as NSURL, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: "downloadPath")
            }
        }
    }
    
    var preferredFormat: String {
        get { UserDefaults.standard.string(forKey: "preferredFormat") ?? "mp4" }
        set { UserDefaults.standard.set(newValue, forKey: "preferredFormat") }
    }
    
    var preferredQuality: String {
        get { UserDefaults.standard.string(forKey: "preferredQuality") ?? "1080p" }
        set { UserDefaults.standard.set(newValue, forKey: "preferredQuality") }
    }
    
    // MARK: - Appearance
    
    var theme: AppTheme {
        get {
            if let raw = UserDefaults.standard.string(forKey: "theme"),
               let theme = AppTheme(rawValue: raw) {
                return theme
            }
            return .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }
    
    // MARK: - Binary Paths
    
    var ytdlpPath: String {
        get { UserDefaults.standard.string(forKey: "ytdlpPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "ytdlpPath") }
    }
    
    var ffmpegPath: String {
        get { UserDefaults.standard.string(forKey: "ffmpegPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "ffmpegPath") }
    }
    
    // MARK: - Menu Bar
    
    var showInMenuBar: Bool {
        get { UserDefaults.standard.bool(forKey: "showInMenuBar") }
        set { UserDefaults.standard.set(newValue, forKey: "showInMenuBar") }
    }
    
    init() {
        // Set defaults on first launch
        if UserDefaults.standard.object(forKey: "showInMenuBar") == nil {
            UserDefaults.standard.set(true, forKey: "showInMenuBar")
        }
    }
}

/// App theme options
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Available format options
enum FormatOption: String, CaseIterable {
    case mp4 = "mp4"
    case webm = "webm"
    case mp3 = "mp3"
    case m4a = "m4a"
    
    var displayName: String { rawValue.uppercased() }
    
    var isAudio: Bool {
        self == .mp3 || self == .m4a
    }
}

/// Available quality options
enum QualityOption: String, CaseIterable {
    case best = "best"
    case q4k = "4K"
    case q1080p = "1080p"
    case q720p = "720p"
    case q480p = "480p"
    
    var displayName: String { rawValue }
}
