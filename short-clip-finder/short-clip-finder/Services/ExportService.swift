//
//  ExportService.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import AVFoundation

actor ExportService {
    private var isCancelled = false
    private var currentProcess: Process?
    private let faceTrackingService = FaceTrackingService()

    enum ExportError: LocalizedError {
        case ffmpegNotFound
        case exportFailed(String)
        case cancelled
        case invalidClip

        var errorDescription: String? {
            switch self {
            case .ffmpegNotFound: "FFmpeg binary not found. Please reinstall the app."
            case .exportFailed(let msg): "Export failed: \(msg)"
            case .cancelled: "Export was cancelled."
            case .invalidClip: "Invalid clip data."
            }
        }
    }

    // MARK: - Public API

    /// Export multiple clips with progress reporting
    func exportClips(
        clips: [ClipSuggestion],
        videoURL: URL,
        settings: ExportSettings,
        progressHandler: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> [URL] {
        isCancelled = false

        // Ensure output directory exists
        try FileManager.default.createDirectory(
            at: settings.outputDirectory,
            withIntermediateDirectories: true
        )

        var exportedURLs: [URL] = []

        for (index, clip) in clips.enumerated() {
            if isCancelled { throw ExportError.cancelled }

            let outputURL = generateOutputURL(
                for: clip,
                in: settings.outputDirectory,
                index: index
            )

            // Report starting
            progressHandler(ExportProgress(
                jobId: clip.id,
                progress: 0,
                status: .detectingFaces,
                outputURL: nil
            ))

            do {
                // Get crop track (face detection)
                let cropTrack: CropTrack
                if settings.cropMode == .autoTrack {
                    cropTrack = try await faceTrackingService.generateCropTrack(
                        videoURL: videoURL,
                        startTime: clip.startTime,
                        endTime: clip.endTime
                    ) { faceProgress in
                        progressHandler(ExportProgress(
                            jobId: clip.id,
                            progress: faceProgress * 0.3,  // Face detection is 30% of work
                            status: .detectingFaces,
                            outputURL: nil
                        ))
                    }
                } else {
                    // Center crop - create empty track
                    let size = try await getVideoSize(url: videoURL)
                    cropTrack = CropTrack(
                        keyframes: [],
                        videoWidth: size.width,
                        videoHeight: size.height
                    )
                }

                if isCancelled { throw ExportError.cancelled }

                // Report encoding starting
                progressHandler(ExportProgress(
                    jobId: clip.id,
                    progress: 0.3,
                    status: .encoding,
                    outputURL: nil
                ))

                // Run FFmpeg export
                try await runFFmpegExport(
                    inputURL: videoURL,
                    outputURL: outputURL,
                    clip: clip,
                    cropTrack: cropTrack,
                    settings: settings
                ) { encodeProgress in
                    progressHandler(ExportProgress(
                        jobId: clip.id,
                        progress: 0.3 + (encodeProgress * 0.7),  // Encoding is 70% of work
                        status: .encoding,
                        outputURL: nil
                    ))
                }

                // Report completed
                progressHandler(ExportProgress(
                    jobId: clip.id,
                    progress: 1.0,
                    status: .completed,
                    outputURL: outputURL
                ))

                exportedURLs.append(outputURL)

            } catch {
                progressHandler(ExportProgress(
                    jobId: clip.id,
                    progress: 0,
                    status: .failed(error.localizedDescription),
                    outputURL: nil
                ))
                throw error
            }
        }

        return exportedURLs
    }

    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        Task {
            await faceTrackingService.cancel()
        }
    }

    // MARK: - Private

    private func getFFmpegPath() throws -> URL {
        // Check Application Support first (for updates)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipFinder")
        let updatedPath = appSupport.appendingPathComponent("ffmpeg")

        if FileManager.default.isExecutableFile(atPath: updatedPath.path) {
            return updatedPath
        }

        // Fall back to bundled binary
        if let bundledPath = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            return bundledPath
        }

        // Development fallback
        let devPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/ffmpeg")

        if FileManager.default.isExecutableFile(atPath: devPath.path) {
            return devPath
        }

        throw ExportError.ffmpegNotFound
    }

    private func getVideoSize(url: URL) async throws -> CGSize {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.invalidClip
        }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let transformedSize = size.applying(transform)
        return CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
    }

    private func generateOutputURL(for clip: ClipSuggestion, in directory: URL, index: Int) -> URL {
        // Create safe filename from hook quote
        let safeTitle = clip.hookQuote
            .prefix(50)
            .replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")

        let filename = "\(String(format: "%02d", index + 1))_\(safeTitle).mp4"
        return directory.appendingPathComponent(filename)
    }

    private func runFFmpegExport(
        inputURL: URL,
        outputURL: URL,
        clip: ClipSuggestion,
        cropTrack: CropTrack,
        settings: ExportSettings,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        let ffmpegPath = try getFFmpegPath()
        let duration = clip.endTime - clip.startTime

        // Build FFmpeg arguments
        // Input FIRST, then seek AFTER input for frame-accurate cutting
        var args: [String] = [
            "-y",  // Overwrite output
            "-i", inputURL.path,  // Input FIRST
            "-ss", String(format: "%.3f", clip.startTime),  // Seek AFTER input for accuracy
            "-t", String(format: "%.3f", duration),
        ]

        // Video filters
        var filters: [String] = []

        // Add crop filter for non-horizontal formats
        if settings.format != .horizontal {
            let cropFilter = cropTrack.ffmpegCropFilter()
            filters.append(cropFilter)
            print("[ExportService] Crop filter: \(cropFilter)")
        }

        // Add scale filter with even dimensions
        let width = settings.quality.width(for: settings.format)
        let height = settings.quality.height
        let scaleFilter = "scale=\(width):\(height):flags=lanczos"
        filters.append(scaleFilter)
        print("[ExportService] Scale filter: \(scaleFilter) (source: \(Int(cropTrack.videoWidth))x\(Int(cropTrack.videoHeight)))")

        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }

        // High quality encoding settings
        args += [
            "-c:v", "libx264",
            "-preset", "slow",        // Better compression, higher quality
            "-crf", "18",             // High quality (18-20 is visually lossless)
            "-profile:v", "high",     // H.264 High Profile for better quality
            "-level", "4.1",          // Compatibility level
            "-pix_fmt", "yuv420p",    // Standard pixel format for compatibility
            "-c:a", "aac",
            "-b:a", "192k",           // Higher audio bitrate
            "-ar", "48000",           // 48kHz audio
            "-movflags", "+faststart",
            "-progress", "pipe:1",
            outputURL.path
        ]

        print("[ExportService] FFmpeg args: \(args.joined(separator: " "))")

        let process = Process()
        process.executableURL = ffmpegPath
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        currentProcess = process

        // Parse progress from stdout
        var progressData = Data()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            progressData.append(data)

            if let output = String(data: data, encoding: .utf8) {
                self.parseProgress(output: output, duration: duration, handler: progressHandler)
            }
        }

        try process.run()

        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        currentProcess = nil

        if isCancelled {
            try? FileManager.default.removeItem(at: outputURL)
            throw ExportError.cancelled
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let fullOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("[ExportService] FFmpeg stderr: \(fullOutput)")

            // Extract just the actual error message (last few lines typically contain the error)
            let lines = fullOutput.components(separatedBy: "\n")
            let errorLines = lines.suffix(10).filter { !$0.isEmpty }
            let errorMsg = errorLines.joined(separator: "\n")

            throw ExportError.exportFailed(errorMsg.isEmpty ? "FFmpeg failed with exit code \(process.terminationStatus)" : errorMsg)
        }

        print("[ExportService] Export completed: \(outputURL.lastPathComponent)")
    }

    nonisolated private func parseProgress(
        output: String,
        duration: TimeInterval,
        handler: @escaping @Sendable (Double) -> Void
    ) {
        // Parse: out_time_ms=12345678
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("out_time_ms=") {
                let value = line.replacingOccurrences(of: "out_time_ms=", with: "")
                if let ms = Double(value) {
                    let seconds = ms / 1_000_000
                    let progress = min(1.0, seconds / duration)
                    Task { @MainActor in
                        handler(progress)
                    }
                }
            }
        }
    }
}
