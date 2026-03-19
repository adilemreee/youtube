//
//  DownloadManager.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import Foundation
import SwiftUI
import UserNotifications

/// Represents an active download with progress tracking
@Observable
class ActiveDownload: Identifiable {
    let id: UUID
    var url: String
    var title: String
    var filePath: String = ""
    var progress: Double = 0
    var speed: String = ""
    var eta: String = ""
    var status: DownloadStatus = .pending
    var outputLog: String = ""
    var error: String?
    
    init(id: UUID = UUID(), url: String, title: String = "") {
        self.id = id
        self.url = url
        self.title = title
    }
}

/// Manages all download operations
@Observable
@MainActor
class DownloadManager {
    
    // MARK: - Properties
    
    private let shell = ShellRunner()
    
    /// All active downloads
    var activeDownloads: [ActiveDownload] = []
    
    /// Download queue for sequential processing
    private var downloadQueue: [(url: String, format: String, quality: String)] = []
    
    /// Is currently processing the queue
    var isProcessingQueue: Bool = false
    
    /// Currently fetched video info
    var currentVideoInfo: VideoInfo?
    
    /// Current playlist info
    var currentPlaylistInfo: PlaylistInfo?
    
    /// Log output for terminal view
    var terminalOutput: String = ""
    
    /// Is currently fetching video info
    var isFetching: Bool = false
    
    /// Last error message
    var lastError: String?
    
    /// Shared history store
    private let historyStore: DownloadHistoryStore
    
    /// Download settings
    var downloadPath: URL {
        if let custom = UserDefaults.standard.url(forKey: "downloadPath") {
            return custom
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
    
    var preferredFormat: String {
        get { UserDefaults.standard.string(forKey: "preferredFormat") ?? "mp4" }
        set { UserDefaults.standard.set(newValue, forKey: "preferredFormat") }
    }
    
    var preferredQuality: String {
        get { UserDefaults.standard.string(forKey: "preferredQuality") ?? "1080p" }
        set { UserDefaults.standard.set(newValue, forKey: "preferredQuality") }
    }
    
    init(historyStore: DownloadHistoryStore = .shared) {
        self.historyStore = historyStore
    }
    
    // MARK: - URL Sanitization
    
    /// Extract a valid URL from potentially corrupted input
    private func sanitizeURL(_ input: String) -> String {
        // Split by newlines and find the first valid URL
        let lines = input.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                // Also extract URL if it's embedded in text
                if let urlRange = trimmed.range(of: #"https?://[^\s]+"#, options: .regularExpression) {
                    return String(trimmed[urlRange])
                }
                return trimmed
            }
        }
        // Fallback: just trim whitespace
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Video Info
    
    /// Fetch video information from URL
    func fetchVideoInfo(url: String) async {
        let cleanURL = sanitizeURL(url)
        
        isFetching = true
        lastError = nil
        currentVideoInfo = nil
        currentPlaylistInfo = nil
        terminalOutput = ""
        
        appendLog("Fetching video info for: \(cleanURL)\n")
        appendLog("Please wait...\n")
        
        do {
            let output = try await shell.run(
                "yt-dlp",
                arguments: [
                    "--dump-json",
                    "--no-playlist",
                    "--no-warnings",
                    cleanURL
                ]
            )
            
            appendLog("Got response, parsing...\n")
            
            // Parse the JSON output using JSONSerialization for flexibility
            guard let data = output.data(using: .utf8), !output.isEmpty else {
                appendLog("Error: Empty response from yt-dlp\n")
                lastError = "Empty response"
                isFetching = false
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let videoInfo = VideoInfo(from: json) {
                        currentVideoInfo = videoInfo
                        appendLog("✅ Found: \(videoInfo.title)\n")
                        appendLog("Duration: \(videoInfo.durationFormatted)\n")
                        if let uploader = videoInfo.uploader {
                            appendLog("Uploader: \(uploader)\n")
                        }
                    } else {
                        appendLog("⚠️ Could not parse video info from JSON\n")
                        lastError = "Failed to parse video info"
                    }
                } else {
                    appendLog("⚠️ Invalid JSON structure\n")
                    lastError = "Invalid JSON"
                }
            } catch {
                appendLog("⚠️ JSON parse error: \(error.localizedDescription)\n")
                lastError = "Failed to parse video info"
            }
            
        } catch let error as ShellError {
            lastError = error.localizedDescription
            appendLog("❌ Error: \(error.localizedDescription)\n")
        } catch {
            lastError = error.localizedDescription
            appendLog("❌ Error: \(error.localizedDescription)\n")
        }
        
        isFetching = false
    }
    
    /// Fetch playlist information from URL
    func fetchPlaylistInfo(url: String) async {
        let cleanURL = sanitizeURL(url)
        
        isFetching = true
        lastError = nil
        currentVideoInfo = nil
        currentPlaylistInfo = nil
        terminalOutput = ""
        
        appendLog("Fetching playlist info for: \(cleanURL)\n")
        appendLog("Please wait...\n")
        
        do {
            let output = try await shell.run(
                "yt-dlp",
                arguments: [
                    "--dump-single-json",
                    "--yes-playlist",
                    "--no-warnings",
                    cleanURL
                ]
            )
            
            appendLog("Got response, parsing...\n")
            
            guard let data = output.data(using: .utf8), !output.isEmpty else {
                appendLog("Error: Empty response from yt-dlp\n")
                lastError = "Empty response"
                isFetching = false
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let playlistInfo = parsePlaylistInfo(from: json, sourceURL: cleanURL) {
                    currentPlaylistInfo = playlistInfo
                    appendLog("✅ Found playlist: \(playlistInfo.title)\n")
                    appendLog("Entries: \(playlistInfo.entries.count)\n")
                    if let uploader = playlistInfo.uploader {
                        appendLog("Uploader: \(uploader)\n")
                    }
                } else {
                    appendLog("⚠️ Could not parse playlist info from JSON\n")
                    lastError = "Failed to parse playlist info"
                }
            } catch {
                appendLog("⚠️ JSON parse error: \(error.localizedDescription)\n")
                lastError = "Failed to parse playlist info"
            }
            
        } catch let error as ShellError {
            lastError = error.localizedDescription
            appendLog("❌ Error: \(error.localizedDescription)\n")
        } catch {
            lastError = error.localizedDescription
            appendLog("❌ Error: \(error.localizedDescription)\n")
        }
        
        isFetching = false
    }
    
    // MARK: - Download
    
    /// Add a download to the queue
    func addToQueue(
        url: String,
        format: String = "mp4",
        quality: String = "best"
    ) {
        let cleanURL = sanitizeURL(url)
        downloadQueue.append((url: cleanURL, format: format, quality: quality))
        appendLog("📥 Added to queue: \(cleanURL)\n")
        appendLog("Queue size: \(downloadQueue.count)\n")
        
        // Start processing if not already
        if !isProcessingQueue {
            Task {
                await processQueue()
            }
        }
    }
    
    /// Process the download queue sequentially
    private func processQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        
        while !downloadQueue.isEmpty {
            let item = downloadQueue.removeFirst()
            await startDownload(url: item.url, format: item.format, quality: item.quality)
        }
        
        isProcessingQueue = false
    }
    
    /// Start a download (internal - called by queue processor)
    func startDownload(
        url: String,
        format: String = "mp4",
        quality: String = "best"
    ) async {
        let cleanURL = sanitizeURL(url)
        
        let download = ActiveDownload(url: cleanURL)
        download.status = .fetching
        activeDownloads.append(download)
        
        appendLog("\n--- Starting Download ---\n")
        appendLog("URL: \(cleanURL)\n")
        appendLog("Format: \(format), Quality: \(quality)\n\n")
        
        // Build yt-dlp arguments
        var arguments = [
            "--newline",
            "--progress",
            "-o", downloadPath.appendingPathComponent("%(title)s.%(ext)s").path
        ]
        
        // Add format selection
        if format == "mp3" || format == "m4a" {
            arguments += ["-x", "--audio-format", format]
        } else {
            let formatString = buildFormatString(quality: quality, format: format)
            arguments += ["-f", formatString]
            // Force output format to mp4
            if format == "mp4" {
                arguments += ["--merge-output-format", "mp4"]
            } else if format == "webm" {
                arguments += ["--merge-output-format", "webm"]
            }
        }
        
        arguments.append(cleanURL)
        
        download.status = .downloading
        
        do {
            let exitCode = try await shell.runWithStream(
                "yt-dlp",
                arguments: arguments,
                workingDirectory: downloadPath
            ) { [weak self] output in
                guard let self = self else { return }
                self.appendLog(output)
                self.parseProgress(output, for: download)
            }
            
            if exitCode == 0 {
                download.status = .completed
                download.progress = 1.0
                appendLog("\n✅ Download completed!\n")
                
                saveToHistory(download: download, format: format, quality: quality)
                
                // Send notification
                sendNotification(title: "Download Complete", body: download.title.isEmpty ? "Video downloaded successfully" : download.title)
            } else {
                download.status = .failed
                download.error = "Download failed with exit code \(exitCode)"
                appendLog("\n❌ Download failed\n")
                sendNotification(title: "Download Failed", body: "An error occurred while downloading")
            }
        } catch {
            download.status = .failed
            download.error = error.localizedDescription
            appendLog("\n❌ Error: \(error.localizedDescription)\n")
            sendNotification(title: "Download Error", body: error.localizedDescription)
        }
    }
    
    // MARK: - Notifications
    
    /// Request notification permission
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    /// Send a local notification
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Get queue count
    var queueCount: Int {
        downloadQueue.count
    }
    
    /// Cancel a download
    func cancelDownload(_ download: ActiveDownload) {
        download.status = .cancelled
        // In a full implementation, we'd need to track the Process and terminate it
        if let index = activeDownloads.firstIndex(where: { $0.id == download.id }) {
            activeDownloads.remove(at: index)
        }
    }
    
    /// Remove completed/failed downloads from active list
    func clearCompleted() {
        activeDownloads.removeAll { !$0.status.isActive }
    }
    
    // MARK: - Private Helpers
    
    private func appendLog(_ text: String) {
        terminalOutput += text
    }
    
    private func buildFormatString(quality: String, format: String) -> String {
        // Prefer H.264 (avc1) codec for macOS QuickTime compatibility
        // VP9 and AV1 codecs may not play correctly in QuickTime
        switch quality {
        case "4K", "2160p":
            return "bestvideo[height<=2160][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=2160]+bestaudio/best[height<=2160]"
        case "1080p":
            return "bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]"
        case "720p":
            return "bestvideo[height<=720][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=720]+bestaudio/best[height<=720]"
        case "480p":
            return "bestvideo[height<=480][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=480]+bestaudio/best[height<=480]"
        default:
            return "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo+bestaudio/best"
        }
    }
    
    private func parseProgress(_ output: String, for download: ActiveDownload) {
        // Parse yt-dlp progress output
        // Example: [download] 45.2% of 125.30MiB at 2.50MiB/s ETA 00:32
        
        // Capture destination file path
        // Example: [download] Destination: /path/to/file.mp4
        // Or: [Merger] Merging formats into "/path/to/file.mp4"
        if output.contains("Destination:") {
            if let range = output.range(of: "Destination: ") {
                let pathStart = output[range.upperBound...]
                let path = pathStart.trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty {
                    download.filePath = path
                }
            }
        }
        
        // Also capture merged file path
        if output.contains("Merging formats into") {
            if let startRange = output.range(of: "\""),
               let endRange = output.range(of: "\"", range: startRange.upperBound..<output.endIndex) {
                let path = String(output[startRange.upperBound..<endRange.lowerBound])
                if !path.isEmpty {
                    download.filePath = path
                }
            }
        }
        
        if let titleMatch = output.range(of: #"\[download\] Destination: (.+)"#, options: .regularExpression) {
            let title = String(output[titleMatch]).replacingOccurrences(of: "[download] Destination: ", with: "")
            download.title = URL(fileURLWithPath: title).deletingPathExtension().lastPathComponent
        }
        
        if let percentMatch = output.range(of: #"(\d+\.?\d*)%"#, options: .regularExpression) {
            let percentStr = String(output[percentMatch]).replacingOccurrences(of: "%", with: "")
            if let percent = Double(percentStr) {
                download.progress = percent / 100.0
            }
        }
        
        if let speedMatch = output.range(of: #"at\s+(\d+\.?\d*\w+/s)"#, options: .regularExpression) {
            let speedStr = String(output[speedMatch]).replacingOccurrences(of: "at ", with: "")
            download.speed = speedStr
        }
        
        if let etaMatch = output.range(of: #"ETA\s+(\d+:\d+)"#, options: .regularExpression) {
            let etaStr = String(output[etaMatch]).replacingOccurrences(of: "ETA ", with: "")
            download.eta = etaStr
        }
    }
    
    private func saveToHistory(download: ActiveDownload, format: String, quality: String) {
        // Use the captured file path, or construct one as fallback
        var finalPath = download.filePath
        if finalPath.isEmpty {
            finalPath = downloadPath.appendingPathComponent("\(download.title).\(format)").path
        }
        
        // Get file size
        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: finalPath),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        
        let item = DownloadHistoryItem(
            id: download.id,
            title: download.title.isEmpty ? "Unknown" : download.title,
            url: download.url,
            filePath: finalPath,
            format: format,
            quality: quality,
            dateCreated: Date(),
            fileSize: fileSize,
            duration: nil
        )
        historyStore.add(item)
        
        appendLog("Saved to history: \(finalPath)\n")
    }
    
    private func parsePlaylistInfo(from dict: [String: Any], sourceURL: String) -> PlaylistInfo? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String else {
            return nil
        }
        
        let playlistHost = URL(string: sourceURL)?.host?.lowercased() ?? ""
        let entryDictionaries = dict["entries"] as? [[String: Any]] ?? []
        
        let entries: [PlaylistEntry] = entryDictionaries.compactMap { entry -> PlaylistEntry? in
            guard let entryID = entry["id"] as? String else {
                return nil
            }
            
            return PlaylistEntry(
                id: entryID,
                title: entry["title"] as? String,
                duration: doubleValue(from: entry["duration"]),
                thumbnail: entry["thumbnail"] as? String,
                url: resolvePlaylistEntryURL(from: entry, playlistHost: playlistHost)
            )
        }
        
        guard !entries.isEmpty else {
            return nil
        }
        
        return PlaylistInfo(
            id: id,
            title: title,
            thumbnail: dict["thumbnail"] as? String,
            uploader: dict["uploader"] as? String ?? dict["channel"] as? String,
            entries: entries
        )
    }
    
    private func resolvePlaylistEntryURL(from dict: [String: Any], playlistHost: String) -> String? {
        if let webpageURL = dict["webpage_url"] as? String, !webpageURL.isEmpty {
            return webpageURL
        }
        
        if let originalURL = dict["original_url"] as? String, !originalURL.isEmpty {
            return originalURL
        }
        
        if let url = dict["url"] as? String, !url.isEmpty {
            if url.hasPrefix("http://") || url.hasPrefix("https://") {
                return url
            }
            
            let extractorKey = (dict["extractor_key"] as? String ?? "").lowercased()
            if extractorKey.contains("youtube") || playlistHost.contains("youtu") {
                return "https://www.youtube.com/watch?v=\(url)"
            }
        }
        
        return nil
    }
    
    private func doubleValue(from value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
    
    // MARK: - Computed Properties
    
    var hasActiveDownloads: Bool {
        activeDownloads.contains { $0.status.isActive }
    }
    
    var completedDownloads: [ActiveDownload] {
        activeDownloads.filter { $0.status == .completed }
    }
    
    var recentDownloads: [ActiveDownload] {
        Array(activeDownloads.suffix(3))
    }
}
