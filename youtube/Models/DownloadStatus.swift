//
//  DownloadStatus.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import Foundation

/// Status of a download item
enum DownloadStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case fetching = "fetching"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .fetching: return "Fetching Info..."
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .fetching: return "magnifyingglass"
        case .downloading: return "arrow.down.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .pending, .fetching, .downloading:
            return true
        default:
            return false
        }
    }
}
