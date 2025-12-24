//
//  ClipboardManager.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import Foundation
import AppKit

/// Manages clipboard operations and URL detection
@Observable
@MainActor
class ClipboardManager {
    
    static let shared = ClipboardManager()
    
    /// Current clipboard text
    var clipboardText: String?
    
    /// Whether the clipboard contains a valid video URL
    var hasValidURL: Bool {
        guard let text = clipboardText else { return false }
        return isValidVideoURL(text)
    }
    
    /// The detected video URL from clipboard
    var detectedURL: String? {
        guard let text = clipboardText, isValidVideoURL(text) else { return nil }
        return text
    }
    
    /// Supported video domains
    private let supportedDomains = [
        "youtube.com",
        "youtu.be",
        "vimeo.com",
        "dailymotion.com",
        "twitch.tv",
        "twitter.com",
        "x.com",
        "instagram.com",
        "tiktok.com",
        "facebook.com",
        "reddit.com"
    ]
    
    init() {
        updateFromClipboard()
    }
    
    /// Check current clipboard and update state
    func updateFromClipboard() {
        let pasteboard = NSPasteboard.general
        clipboardText = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Copy text to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Check if a string is a valid video URL
    func isValidVideoURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let host = url.host?.lowercased() else {
            return false
        }
        
        return supportedDomains.contains { domain in
            host.contains(domain)
        }
    }
    
    /// Extract video ID from YouTube URL
    func extractYouTubeVideoID(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Handle youtu.be short links
        if url.host?.contains("youtu.be") == true {
            return url.lastPathComponent
        }
        
        // Handle youtube.com/watch?v=ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoID
        }
        
        // Handle youtube.com/embed/ID
        if url.pathComponents.contains("embed"),
           let index = url.pathComponents.firstIndex(of: "embed"),
           url.pathComponents.count > index + 1 {
            return url.pathComponents[index + 1]
        }
        
        return nil
    }
    
    /// Get platform name from URL
    func getPlatformName(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return "Video"
        }
        
        if host.contains("youtube") || host.contains("youtu.be") {
            return "YouTube"
        } else if host.contains("vimeo") {
            return "Vimeo"
        } else if host.contains("twitch") {
            return "Twitch"
        } else if host.contains("twitter") || host.contains("x.com") {
            return "X/Twitter"
        } else if host.contains("instagram") {
            return "Instagram"
        } else if host.contains("tiktok") {
            return "TikTok"
        } else if host.contains("dailymotion") {
            return "Dailymotion"
        } else if host.contains("facebook") {
            return "Facebook"
        } else if host.contains("reddit") {
            return "Reddit"
        }
        
        return "Video"
    }
}
