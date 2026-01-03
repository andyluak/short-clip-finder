//
//  TranscriptionService.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import WhisperKit
import AVFoundation
import CoreML
import CoreMedia

actor TranscriptionService {
    private var whisperKit: WhisperKit?
    private var currentTask: Task<[TranscriptSegment], Error>?
    private var lastProgressUpdate: CFAbsoluteTime = 0
    private let progressUpdateInterval: CFAbsoluteTime = 0.1  // Throttle to 10 updates/second max

    func loadModel(progressHandler: @escaping @Sendable (Double) -> Void) async throws {
        // Let WhisperKit handle model downloading and caching automatically
        progressHandler(0.1)

        // distil-large-v3 is fastest with good quality (6x faster than large-v3)
        // Falls back to auto-select if not available
        let modelName = "distil-large-v3"

        // print("[TranscriptionService] Loading model: \(modelName)")

        // Configure with VAD for efficient chunking
        // Use all available compute units (CPU + GPU + Neural Engine) for maximum performance
        let config = WhisperKitConfig(
            model: modelName,
            computeOptions: .init(
                melCompute: .cpuAndGPU,           // Feature extraction - GPU accelerated
                audioEncoderCompute: .cpuAndGPU,   // Audio encoding - GPU accelerated
                textDecoderCompute: .cpuAndNeuralEngine  // Text decoding - Neural Engine optimized
            ),
            verbose: false,  // Disable verbose logging for performance
            logLevel: .error  // Only log errors
        )

        whisperKit = try await WhisperKit(config)

        // print("[TranscriptionService] Model loaded successfully")
        progressHandler(1.0)
    }

    func transcribe(
        videoURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> [TranscriptSegment] {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let audioURL = try await extractAudio(from: videoURL)
        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        // Get audio duration for progress calculation
        let audioAsset = AVURLAsset(url: audioURL)
        let duration = try await audioAsset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        // print("[TranscriptionService] Starting transcription of \(String(format: "%.1f", totalSeconds))s audio")

        // Track last progress to throttle updates
        var lastReportedProgress: Double = -1
        let minProgressDelta: Double = 0.02  // Only update if progress changed by 2%+

        let results = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: .init(
                verbose: false,  // Disable verbose for performance
                task: .transcribe,
                language: "en",  // Set language to avoid detection overhead
                wordTimestamps: true
            )
        ) { progress in
            // Use window ID for progress (each window is ~30s)
            let windowEnd = progress.windowId
            let currentTime = Double((windowEnd + 1) * 30)
            let progressValue = totalSeconds > 0 ? min(0.95, currentTime / totalSeconds) : 0

            // Throttle progress updates to reduce Task creation overhead
            if progressValue - lastReportedProgress >= minProgressDelta {
                lastReportedProgress = progressValue
                Task { @MainActor in
                    progressHandler(progressValue)
                }
            }
            return nil  // Return nil to continue (false would cancel)
        }

        guard let result = results.first else {
            throw TranscriptionError.noResults
        }

        return convertToSegments(result)
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")

        // print("[TranscriptionService] Extracting audio from: \(videoURL.path)")
        // print("[TranscriptionService] Video extension: \(videoURL.pathExtension)")

        // Check available audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        // print("[TranscriptionService] Audio tracks found: \(audioTracks.count)")

        if audioTracks.isEmpty {
            print("[TranscriptionService] ERROR: No audio tracks in video")
            throw TranscriptionError.audioExtractionFailed
        }

        // Check available presets for this asset
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        // print("[TranscriptionService] Compatible presets: \(compatiblePresets)")

        // Try M4A first, fall back to passthrough
        let presetToUse: String
        if compatiblePresets.contains(AVAssetExportPresetAppleM4A) {
            presetToUse = AVAssetExportPresetAppleM4A
        } else if compatiblePresets.contains(AVAssetExportPresetPassthrough) {
            presetToUse = AVAssetExportPresetPassthrough
        } else {
            print("[TranscriptionService] ERROR: No compatible audio export preset")
            throw TranscriptionError.audioExtractionFailed
        }

        // print("[TranscriptionService] Using preset: \(presetToUse)")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetToUse) else {
            print("[TranscriptionService] ERROR: Could not create export session")
            throw TranscriptionError.audioExtractionFailed
        }

        exportSession.outputURL = audioURL
        exportSession.outputFileType = presetToUse == AVAssetExportPresetAppleM4A ? .m4a : .m4a

        await exportSession.export()

        if exportSession.status != .completed {
            print("[TranscriptionService] Export failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            throw TranscriptionError.audioExtractionFailed
        }

        // print("[TranscriptionService] Audio extracted to: \(audioURL.path)")
        return audioURL
    }

    private func convertToSegments(_ result: TranscriptionResult) -> [TranscriptSegment] {
        result.segments.map { segment in
            let words: [TranscriptWord] = (segment.words ?? []).map { word in
                TranscriptWord(
                    text: cleanText(word.word),
                    start: TimeInterval(word.start),
                    end: TimeInterval(word.end)
                )
            }
            return TranscriptSegment(
                text: cleanText(segment.text),
                start: TimeInterval(segment.start),
                end: TimeInterval(segment.end),
                words: words
            )
        }
    }

    private func cleanText(_ text: String) -> String {
        // Remove WhisperKit special tokens like <|startoftranscript|>, <|en|>, <|0.00|>, etc.
        var cleaned = text
        let tokenPattern = #"<\|[^|]*\|>"#
        if let regex = try? NSRegularExpression(pattern: tokenPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case noResults
    case audioExtractionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Whisper model not loaded. Please download the model first."
        case .noResults:
            "No transcription results returned."
        case .audioExtractionFailed:
            "Failed to extract audio from video."
        }
    }
}
