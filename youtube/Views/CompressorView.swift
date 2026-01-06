//
//  CompressorView.swift
//  youtube
//
//  Created by Adil Emre Karayürek on 25.12.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct CompressorView: View {
    @State private var compressorService = CompressorService()
    @State private var selectedFile: URL?
    @State private var operationType: OperationType = .compress
    @State private var compressionPreset: CompressionPreset = .medium
    @State private var audioFormat: AudioFormat = .mp3
    @State private var isDropTargeted: Bool = false
    @State private var showFilePicker: Bool = false
    
    enum OperationType: String, CaseIterable {
        case compress = "Compress Video"
        case extractAudio = "Extract Audio"
        case trim = "Trim Video"
        
        var icon: String {
            switch self {
            case .compress: return "arrow.down.right.and.arrow.up.left"
            case .extractAudio: return "music.note"
            case .trim: return "scissors"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            ScrollView {
                VStack(spacing: 20) {
                    // Drop Zone
                    dropZone
                    
                    // Operation Type
                    operationPicker
                    
                    // Options
                    optionsSection
                    
                    // Process Button
                    processButton
                    
                    // Output Log
                    if !compressorService.outputLog.isEmpty {
                        outputSection
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.movie, .video, .audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedFile = url
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Media Compressor")
                    .font(.title.bold())
                
                Text("Compress videos, extract audio, and more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Drop Zone
    
    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                )
            
            VStack(spacing: 12) {
                if let file = selectedFile {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    
                    Text(file.lastPathComponent)
                        .font(.headline)
                    
                    Button("Choose Different File") {
                        showFilePicker = true
                    }
                    .buttonStyle(.bordered)
                } else {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Drop a video file here")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Button("Choose File") {
                        showFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(height: 180)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - Operation Picker
    
    private var operationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operation")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(OperationType.allCases, id: \.self) { type in
                    Button {
                        operationType = type
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(operationType == type ? .accentColor : .secondary)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
            
            switch operationType {
            case .compress:
                Picker("Quality Preset", selection: $compressionPreset) {
                    ForEach(CompressionPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                
            case .extractAudio:
                Picker("Audio Format", selection: $audioFormat) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
            case .trim:
                Text("Trim functionality coming soon...")
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Process Button
    
    private var processButton: some View {
        Button {
            Task {
                await processFile()
            }
        } label: {
            HStack {
                if compressorService.currentJob?.isComplete == false {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text("Process")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle(colors: [.green, .teal]))
        .disabled(selectedFile == nil || compressorService.currentJob?.isComplete == false)
    }
    
    // MARK: - Output Section
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.secondary)
                    Text("Output")
                        .font(.headline)
                }
                
                Spacer()
                
                // Status indicator
                if let job = compressorService.currentJob {
                    HStack(spacing: 6) {
                        if job.isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(job.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
            }
            
            // Content
            ScrollView {
                Text(compressorService.outputLog)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(height: 150)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .cardStyle()
    }
    
    // MARK: - Actions
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    selectedFile = url
                }
            }
        }
        return true
    }
    
    private func processFile() async {
        guard let file = selectedFile else { return }
        
        do {
            switch operationType {
            case .compress:
                try await compressorService.compressVideo(from: file, preset: compressionPreset)
            case .extractAudio:
                try await compressorService.extractAudio(from: file, format: audioFormat)
            case .trim:
                // Coming soon
                break
            }
        } catch {
            // Error is handled in the service
        }
    }
}

#Preview {
    CompressorView()
        .frame(width: 600, height: 700)
}
