//
//  VideoInfo.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import Foundation

/// Represents video metadata fetched from yt-dlp
/// Uses minimal fields to avoid JSON parsing issues with varying yt-dlp output
struct VideoInfo: Identifiable {
    var id: String
    var title: String
    var thumbnail: String?
    var duration: Double?
    var uploader: String?
    var channel: String?
    var viewCount: Int?
    var description: String?
    
    var durationFormatted: String {
        guard let duration = duration else { return "--:--" }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Parse from yt-dlp JSON dictionary
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.thumbnail = dict["thumbnail"] as? String
        self.duration = dict["duration"] as? Double
        self.uploader = dict["uploader"] as? String
        self.channel = dict["channel"] as? String
        self.viewCount = dict["view_count"] as? Int
        self.description = dict["description"] as? String
    }
}

/// VideoFormat - kept simple
struct VideoFormat: Identifiable {
    var id: String { formatId }
    var formatId: String
    var ext: String
    var resolution: String?
    var formatNote: String?
    
    init?(from dict: [String: Any]) {
        guard let formatId = dict["format_id"] as? String,
              let ext = dict["ext"] as? String else {
            return nil
        }
        self.formatId = formatId
        self.ext = ext
        self.resolution = dict["resolution"] as? String
        self.formatNote = dict["format_note"] as? String
    }
}

/// Represents a playlist with multiple videos
struct PlaylistInfo: Identifiable, Codable {
    var id: String
    var title: String
    var thumbnail: String?
    var uploader: String?
    var entries: [PlaylistEntry]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case thumbnail
        case uploader
        case entries
    }
}

/// Represents a single entry in a playlist
struct PlaylistEntry: Identifiable, Codable, Hashable {
    var id: String
    var title: String?
    var duration: Double?
    var thumbnail: String?
    var url: String?
    
    var durationFormatted: String {
        guard let duration = duration else { return "--:--" }
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case thumbnail
        case url = "webpage_url"
    }
}
