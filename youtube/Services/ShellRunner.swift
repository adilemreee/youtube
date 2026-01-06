//
//  ShellRunner.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import Foundation

/// Error types for shell command execution
enum ShellError: LocalizedError {
    case binaryNotFound(String)
    case executionFailed(String)
    case invalidOutput
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "Binary not found: \(name). Please install it via Homebrew."
        case .executionFailed(let message):
            return "Command failed: \(message)"
        case .invalidOutput:
            return "Invalid output from command"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}

/// Wrapper around Process for safe CLI execution
class ShellRunner: @unchecked Sendable {
    
    /// Default paths to search for binaries
    private let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]
    
    /// Find the path to a binary
    func findBinary(_ name: String, customPath: String? = nil) -> String? {
        if let custom = customPath, FileManager.default.fileExists(atPath: custom) {
            return custom
        }
        
        for path in searchPaths {
            let fullPath = "\(path)/\(name)"
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }
    
    /// Run a command and return the output
    func run(
        _ command: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) async throws -> String {
        guard let binaryPath = findBinary(command) else {
            throw ShellError.binaryNotFound(command)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: binaryPath)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = errorPipe
                
                if let dir = workingDirectory {
                    process.currentDirectoryURL = dir
                }
                
                // Set environment with PATH
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                if let customEnv = environment {
                    for (key, value) in customEnv {
                        env[key] = value
                    }
                }
                process.environment = env
                
                // Collect output data asynchronously to avoid pipe buffer deadlock
                var outputData = Data()
                var errorData = Data()
                let outputLock = NSLock()
                let errorLock = NSLock()
                
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputLock.lock()
                        outputData.append(data)
                        outputLock.unlock()
                    }
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        errorLock.lock()
                        errorData.append(data)
                        errorLock.unlock()
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    // Clean up handlers
                    pipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    // Read any remaining data
                    outputLock.lock()
                    outputData.append(pipe.fileHandleForReading.readDataToEndOfFile())
                    outputLock.unlock()
                    
                    errorLock.lock()
                    errorData.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
                    errorLock.unlock()
                    
                    if process.terminationStatus == 0 {
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } else {
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ShellError.executionFailed(errorOutput))
                    }
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Run a command with real-time output streaming
    func runWithStream(
        _ command: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        guard let binaryPath = findBinary(command) else {
            throw ShellError.binaryNotFound(command)
        }
        
        return try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            
            if let dir = workingDirectory {
                process.currentDirectoryURL = dir
            }
            
            // Set up environment with PATH
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            process.environment = env
            
            // Use a semaphore to wait for process completion
            let semaphore = DispatchSemaphore(value: 0)
            var exitCode: Int32 = -1
            
            // Read output in real-time on a background queue
            let outputQueue = DispatchQueue(label: "shell.output")
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        onOutput(output)
                    }
                }
            }
            
            process.terminationHandler = { proc in
                outputQueue.async {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    exitCode = proc.terminationStatus
                    semaphore.signal()
                }
            }
            
            try process.run()
            
            // Wait for process to complete (with timeout of 10 minutes)
            let result = semaphore.wait(timeout: .now() + 600)
            
            if result == .timedOut {
                process.terminate()
                throw ShellError.executionFailed("Process timed out")
            }
            
            return exitCode
        }.value
    }
    
    /// Simple synchronous run for quick commands
    func runSync(
        _ command: String,
        arguments: [String]
    ) throws -> String {
        guard let binaryPath = findBinary(command) else {
            throw ShellError.binaryNotFound(command)
        }
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = env
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
