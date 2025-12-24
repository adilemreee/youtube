//
//  DownloadItem.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import Foundation
import SwiftData

/// Represents a downloaded or in-progress video/audio file
@Model
final class DownloadItem {
    var id: UUID
    var title: String
    var url: String
    var filePath: String
    var format: String // "mp4", "mp3", "m4a", "webm"
    var quality: String // "4K", "1080p", "720p", "480p", "audio"
    @Attribute(.externalStorage) var thumbnailData: Data?
    var dateCreated: Date
    var fileSize: Int64
    var duration: String?
    var statusRaw: String
    
    var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        title: String = "",
        url: String,
        filePath: String = "",
        format: String = "mp4",
        quality: String = "1080p",
        thumbnailData: Data? = nil,
        dateCreated: Date = Date(),
        fileSize: Int64 = 0,
        duration: String? = nil,
        status: DownloadStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.filePath = filePath
        self.format = format
        self.quality = quality
        self.thumbnailData = thumbnailData
        self.dateCreated = dateCreated
        self.fileSize = fileSize
        self.duration = duration
        self.statusRaw = status.rawValue
    }
}
