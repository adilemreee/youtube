//
//  DownloadHistoryStore.swift
//  youtube
//
//  Created by Codex on 19.03.2026.
//

import Foundation
import SwiftData

struct DownloadHistoryItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var url: String
    var filePath: String
    var format: String
    var quality: String
    var dateCreated: Date
    var fileSize: Int64
    var duration: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        filePath: String,
        format: String,
        quality: String,
        dateCreated: Date = Date(),
        fileSize: Int64 = 0,
        duration: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.filePath = filePath
        self.format = format
        self.quality = quality
        self.dateCreated = dateCreated
        self.fileSize = fileSize
        self.duration = duration
    }
    
    init(from legacyItem: DownloadItem) {
        self.id = legacyItem.id
        self.title = legacyItem.title
        self.url = legacyItem.url
        self.filePath = legacyItem.filePath
        self.format = legacyItem.format
        self.quality = legacyItem.quality
        self.dateCreated = legacyItem.dateCreated
        self.fileSize = legacyItem.fileSize
        self.duration = legacyItem.duration
    }
}

@Observable
@MainActor
final class DownloadHistoryStore {
    static let shared = DownloadHistoryStore()
    
    private(set) var items: [DownloadHistoryItem]
    
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil,
        initialItems: [DownloadHistoryItem]? = nil
    ) {
        self.fileManager = fileManager
        
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let historyDirectory = fileURL?.deletingLastPathComponent()
            ?? appSupportDirectory.appendingPathComponent("VidFlow", isDirectory: true)
        self.fileURL = fileURL ?? historyDirectory.appendingPathComponent("history.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        
        if let initialItems {
            self.items = initialItems.sorted { $0.dateCreated > $1.dateCreated }
        } else {
            self.items = []
            loadItems()
        }
    }
    
    func add(_ item: DownloadHistoryItem) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        persistItems()
    }
    
    func delete(_ item: DownloadHistoryItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }
    
    func clear() {
        items.removeAll()
        persistItems()
    }
    
    private func loadItems() {
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                items = try decoder.decode([DownloadHistoryItem].self, from: data)
                    .sorted { $0.dateCreated > $1.dateCreated }
                return
            } catch {
                print("Failed to load history store: \(error)")
            }
        }
        
        items = importLegacySwiftDataHistory()
        if !items.isEmpty {
            persistItems()
        }
    }
    
    private func persistItems() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save history store: \(error)")
        }
    }
    
    private func importLegacySwiftDataHistory() -> [DownloadHistoryItem] {
        do {
            let container = try ModelContainer(for: DownloadItem.self)
            let descriptor = FetchDescriptor<DownloadItem>(
                sortBy: [SortDescriptor(\DownloadItem.dateCreated, order: .reverse)]
            )
            return try container.mainContext.fetch(descriptor).map(DownloadHistoryItem.init(from:))
        } catch {
            print("Failed to import legacy SwiftData history: \(error)")
            return []
        }
    }
}
