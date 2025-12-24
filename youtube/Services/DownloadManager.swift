//
//  DownloadManager.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import Foundation
import SwiftUI
import SwiftData

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
    
    // MARK: - Download
    
    /// Start a download
    func startDownload(
        url: String,
        format: String = "mp4",
        quality: String = "best",
        modelContext: ModelContext
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
                
                // Save to history
                saveToHistory(download: download, format: format, quality: quality, modelContext: modelContext)
            } else {
                download.status = .failed
                download.error = "Download failed with exit code \(exitCode)"
                appendLog("\n❌ Download failed\n")
            }
        } catch {
            download.status = .failed
            download.error = error.localizedDescription
            appendLog("\n❌ Error: \(error.localizedDescription)\n")
        }
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
    
    private func saveToHistory(download: ActiveDownload, format: String, quality: String, modelContext: ModelContext) {
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
        
        let item = DownloadItem(
            title: download.title.isEmpty ? "Unknown" : download.title,
            url: download.url,
            filePath: finalPath,
            format: format,
            quality: quality,
            dateCreated: Date(),
            fileSize: fileSize,
            status: .completed
        )
        modelContext.insert(item)
        
        appendLog("Saved to history: \(finalPath)\n")
        
        do {
            try modelContext.save()
        } catch {
            appendLog("Failed to save to history: \(error.localizedDescription)\n")
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
