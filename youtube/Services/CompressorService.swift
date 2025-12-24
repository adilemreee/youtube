//
//  CompressorService.swift
//  youtube
//
//  Created by adil emre on 25.12.2025.
//

import Foundation

/// Compression quality presets
enum CompressionPreset: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "High Quality"
        case .medium: return "Medium (Balanced)"
        case .low: return "Low (Smaller Size)"
        }
    }
    
    var crf: Int {
        switch self {
        case .high: return 18
        case .medium: return 23
        case .low: return 28
        }
    }
}

/// Audio format options
enum AudioFormat: String, CaseIterable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case aac = "aac"
    case wav = "wav"
    
    var displayName: String { rawValue.uppercased() }
}

/// Represents a compression/conversion job
@Observable
class CompressionJob: Identifiable {
    let id = UUID()
    var inputPath: URL
    var outputPath: URL?
    var progress: Double = 0
    var status: String = "Pending"
    var isComplete: Bool = false
    var error: String?
    
    init(inputPath: URL) {
        self.inputPath = inputPath
    }
}

/// Service for media compression and conversion using FFmpeg
@Observable
@MainActor
class CompressorService {
    
    private let shell = ShellRunner()
    
    var currentJob: CompressionJob?
    var outputLog: String = ""
    
    /// Check if FFmpeg is available
    func checkFFmpegAvailable() async -> Bool {
        await shell.findBinary("ffmpeg") != nil
    }
    
    /// Convert video to audio
    func extractAudio(
        from inputPath: URL,
        format: AudioFormat = .mp3,
        bitrate: String = "192k"
    ) async throws {
        let outputPath = inputPath
            .deletingPathExtension()
            .appendingPathExtension(format.rawValue)
        
        let job = CompressionJob(inputPath: inputPath)
        job.outputPath = outputPath
        job.status = "Extracting audio..."
        currentJob = job
        
        outputLog = ""
        appendLog("Converting \(inputPath.lastPathComponent) to \(format.displayName)\n")
        
        let arguments = [
            "-i", inputPath.path,
            "-vn",
            "-acodec", format == .mp3 ? "libmp3lame" : format.rawValue,
            "-ab", bitrate,
            "-y",
            outputPath.path
        ]
        
        do {
            let exitCode = try await shell.runWithStream(
                "ffmpeg",
                arguments: arguments
            ) { [weak self] output in
                self?.appendLog(output)
                self?.parseFFmpegProgress(output)
            }
            
            if exitCode == 0 {
                job.status = "Completed"
                job.isComplete = true
                job.progress = 1.0
                appendLog("\n✅ Conversion complete: \(outputPath.lastPathComponent)\n")
            } else {
                throw ShellError.executionFailed("FFmpeg exited with code \(exitCode)")
            }
        } catch {
            job.error = error.localizedDescription
            job.status = "Failed"
            appendLog("\n❌ Error: \(error.localizedDescription)\n")
            throw error
        }
    }
    
    /// Compress video file
    func compressVideo(
        from inputPath: URL,
        preset: CompressionPreset = .medium,
        resolution: String? = nil
    ) async throws {
        let filename = inputPath.deletingPathExtension().lastPathComponent
        let ext = inputPath.pathExtension
        let outputPath = inputPath
            .deletingLastPathComponent()
            .appendingPathComponent("\(filename)_compressed.\(ext)")
        
        let job = CompressionJob(inputPath: inputPath)
        job.outputPath = outputPath
        job.status = "Compressing..."
        currentJob = job
        
        outputLog = ""
        appendLog("Compressing \(inputPath.lastPathComponent)\n")
        appendLog("Preset: \(preset.displayName)\n\n")
        
        var arguments = [
            "-i", inputPath.path,
            "-c:v", "libx264",
            "-crf", String(preset.crf),
            "-preset", "medium",
            "-c:a", "aac",
            "-b:a", "128k"
        ]
        
        if let res = resolution {
            arguments += ["-vf", "scale=-2:\(res)"]
        }
        
        arguments += ["-y", outputPath.path]
        
        do {
            let exitCode = try await shell.runWithStream(
                "ffmpeg",
                arguments: arguments
            ) { [weak self] output in
                self?.appendLog(output)
                self?.parseFFmpegProgress(output)
            }
            
            if exitCode == 0 {
                job.status = "Completed"
                job.isComplete = true
                job.progress = 1.0
                
                // Calculate compression ratio
                if let originalSize = try? FileManager.default.attributesOfItem(atPath: inputPath.path)[.size] as? Int64,
                   let compressedSize = try? FileManager.default.attributesOfItem(atPath: outputPath.path)[.size] as? Int64 {
                    let ratio = Double(compressedSize) / Double(originalSize) * 100
                    appendLog("\n📊 Compression: \(formatBytes(originalSize)) → \(formatBytes(compressedSize)) (\(String(format: "%.1f", ratio))%)\n")
                }
                
                appendLog("✅ Compression complete: \(outputPath.lastPathComponent)\n")
            } else {
                throw ShellError.executionFailed("FFmpeg exited with code \(exitCode)")
            }
        } catch {
            job.error = error.localizedDescription
            job.status = "Failed"
            appendLog("\n❌ Error: \(error.localizedDescription)\n")
            throw error
        }
    }
    
    /// Trim video
    func trimVideo(
        from inputPath: URL,
        startTime: String,
        endTime: String
    ) async throws {
        let filename = inputPath.deletingPathExtension().lastPathComponent
        let ext = inputPath.pathExtension
        let outputPath = inputPath
            .deletingLastPathComponent()
            .appendingPathComponent("\(filename)_trimmed.\(ext)")
        
        let job = CompressionJob(inputPath: inputPath)
        job.outputPath = outputPath
        job.status = "Trimming..."
        currentJob = job
        
        outputLog = ""
        appendLog("Trimming \(inputPath.lastPathComponent)\n")
        appendLog("From \(startTime) to \(endTime)\n\n")
        
        let arguments = [
            "-i", inputPath.path,
            "-ss", startTime,
            "-to", endTime,
            "-c", "copy",
            "-y",
            outputPath.path
        ]
        
        do {
            let exitCode = try await shell.runWithStream(
                "ffmpeg",
                arguments: arguments
            ) { [weak self] output in
                self?.appendLog(output)
            }
            
            if exitCode == 0 {
                job.status = "Completed"
                job.isComplete = true
                job.progress = 1.0
                appendLog("\n✅ Trim complete: \(outputPath.lastPathComponent)\n")
            } else {
                throw ShellError.executionFailed("FFmpeg exited with code \(exitCode)")
            }
        } catch {
            job.error = error.localizedDescription
            job.status = "Failed"
            appendLog("\n❌ Error: \(error.localizedDescription)\n")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func appendLog(_ text: String) {
        outputLog += text
    }
    
    private func parseFFmpegProgress(_ output: String) {
        // Parse FFmpeg progress output
        // Example: frame= 1234 fps=30 q=28.0 size= 12345kB time=00:00:41.23 bitrate=2456.7kbits/s speed=1.23x
        
        // This is a simplified version - full implementation would calculate based on duration
        if output.contains("time=") {
            currentJob?.status = "Processing..."
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
