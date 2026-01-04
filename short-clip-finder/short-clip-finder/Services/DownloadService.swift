//
//  DownloadService.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

actor DownloadService {
    private var currentProcess: Process?
    private var isCancelled = false

    // MARK: - Cached Binary Paths (resolved once, reused)
    private var cachedYTDLPPath: URL?
    private var cachedFFmpegPath: URL?

    // MARK: - Metadata Cache
    private static let metadataCacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours
    private var metadataCache: [String: (metadata: VideoMetadata, timestamp: Date)] = [:]

    enum DownloadError: LocalizedError {
        case ytdlpNotFound
        case invalidURL
        case unsupportedURL
        case downloadFailed(String)
        case metadataFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .ytdlpNotFound:
                "yt-dlp binary not found. Please reinstall the app."
            case .invalidURL:
                "Invalid URL format."
            case .unsupportedURL:
                "This URL is not supported. Try YouTube, Vimeo, or other supported platforms."
            case .downloadFailed(let message):
                "Download failed: \(message)"
            case .metadataFailed:
                "Could not fetch video information."
            case .cancelled:
                "Download was cancelled."
            }
        }
    }

    // MARK: - URL Validation

    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            return false
        }
        return true
    }

    static func isSupportedPlatform(_ urlString: String) -> Bool {
        let supportedPatterns = [
            "youtube.com", "youtu.be",
            "vimeo.com",
            "twitch.tv",
            "twitter.com", "x.com",
            "tiktok.com",
            "instagram.com",
            "facebook.com", "fb.watch",
            "dailymotion.com",
            "soundcloud.com",
            "spotify.com"
        ]

        let lowercased = urlString.lowercased()
        return supportedPatterns.contains { lowercased.contains($0) }
    }

    // MARK: - Metadata

    func fetchMetadata(url: String) async throws -> VideoMetadata {
        // Check cache first
        if let cached = metadataCache[url],
           Date().timeIntervalSince(cached.timestamp) < Self.metadataCacheTTL {
            print("[DownloadService] Using cached metadata for: \(url)")
            return cached.metadata
        }

        let ytdlpPath = try resolveYTDLPPath()
        let cacheDir = getCacheDirectory()

        print("[DownloadService] Using yt-dlp at: \(ytdlpPath.path)")
        print("[DownloadService] Cache directory: \(cacheDir.path)")
        print("[DownloadService] Fetching metadata for: \(url)")

        let process = Process()
        process.executableURL = ytdlpPath

        // Build arguments with performance optimizations
        var arguments = [
            "--dump-json",
            "--no-download",
            "--no-warnings",
            "--ignore-config",      // Skip config file loading for faster startup
            "--no-playlist",        // Don't expand playlists
            "--cache-dir", cacheDir.path,
        ]

        // Add YouTube-specific optimizations
        if url.contains("youtube.com") || url.contains("youtu.be") {
            arguments.append(contentsOf: [
                "--extractor-args", "youtube:player_skip=configs"
            ])
        }

        arguments.append(url)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Collect output data asynchronously to avoid pipe buffer deadlock
        var outputData = Data()
        var errorData = Data()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            outputData.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorData.append(handle.availableData)
        }

        try process.run()
        print("[DownloadService] Process started with PID: \(process.processIdentifier)")

        // Wait for process to complete
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        // Clean up handlers
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        print("[DownloadService] Process exited with status: \(process.terminationStatus)")

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("[DownloadService] yt-dlp failed: \(errorMessage)")
            throw DownloadError.metadataFailed
        }

        do {
            let ytdlpMetadata = try JSONDecoder().decode(YTDLPMetadata.self, from: outputData)
            print("[DownloadService] Successfully parsed metadata: \(ytdlpMetadata.title ?? "unknown")")
            let metadata = ytdlpMetadata.toVideoMetadata()

            // Cache the metadata
            metadataCache[url] = (metadata: metadata, timestamp: Date())

            return metadata
        } catch {
            print("[DownloadService] JSON decode error: \(error)")
            print("[DownloadService] Output size: \(outputData.count) bytes")
            print("[DownloadService] Output was: \(String(data: outputData.prefix(500), encoding: .utf8) ?? "nil")")
            throw DownloadError.metadataFailed
        }
    }

    /// Clear expired metadata cache entries
    func clearExpiredCache() {
        let now = Date()
        metadataCache = metadataCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) < Self.metadataCacheTTL
        }
    }

    private func getCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipFinder")
            .appendingPathComponent("yt-dlp-cache")

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }

    // MARK: - Download

    func download(
        url: String,
        progressHandler: @escaping @Sendable (Double, String) -> Void,
        metadataHandler: (@Sendable (VideoMetadata) -> Void)? = nil
    ) async throws -> (URL, VideoMetadata) {
        isCancelled = false

        guard Self.isValidURL(url) else {
            throw DownloadError.invalidURL
        }

        let ytdlpPath = try resolveYTDLPPath()
        let ffmpegPath = try resolveFFmpegPath()
        let cacheDir = getCacheDirectory()

        // Create temp directory for download
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipFinder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Check cache synchronously first for instant title update
        var notifiedFromCache = false
        if let cached = metadataCache[url],
           Date().timeIntervalSince(cached.timestamp) < Self.metadataCacheTTL {
            metadataHandler?(cached.metadata)
            notifiedFromCache = true
        }

        // Start metadata fetch in parallel with download setup
        // This saves 3-8 seconds by not blocking on metadata before downloading
        let metadataTask = Task { [self] in
            try await self.fetchMetadata(url: url)
        }

        if isCancelled {
            metadataTask.cancel()
            throw DownloadError.cancelled
        }

        // Download video - START IMMEDIATELY, don't wait for metadata
        let outputTemplate = tempDir.appendingPathComponent("%(title)s.%(ext)s").path

        let process = Process()
        process.executableURL = ytdlpPath

        // Build arguments with performance optimizations
        var arguments = [
            "-f", "bv*[height<=1080]+ba/bv*+ba/b",
            "--merge-output-format", "mp4",
            "--ffmpeg-location", ffmpegPath.deletingLastPathComponent().path,
            "-o", outputTemplate,
            "--newline",
            "--no-playlist",
            "--no-warnings",
            "--ignore-config",       // Skip config file loading
            "--cache-dir", cacheDir.path,
            "--socket-timeout", "30",
            "--retries", "3",        // Reduced from 5 for faster failure
            "--fragment-retries", "3", // Reduced from 5
        ]

        // Add YouTube-specific optimizations
        if url.contains("youtube.com") || url.contains("youtu.be") {
            arguments.append(contentsOf: [
                "--extractor-args", "youtube:player_skip=configs"
            ])
        }

        arguments.append(url)
        process.arguments = arguments

        print("[DownloadService] Using FFmpeg at: \(ffmpegPath.path)")
        print("[DownloadService] Format: bv*+ba (best video + best audio, up to 1080p)")
        print("[DownloadService] Starting download immediately (metadata fetching in parallel)")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        currentProcess = process

        // Handle output asynchronously
        let progressTask = Task {
            let handle = outputPipe.fileHandleForReading
            for try await line in handle.bytes.lines {
                if isCancelled { break }
                parseProgress(line: line, progressHandler: progressHandler)
            }
        }

        try process.run()

        // Wait for process in background
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        progressTask.cancel()
        currentProcess = nil

        if isCancelled {
            try? FileManager.default.removeItem(at: tempDir)
            throw DownloadError.cancelled
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            try? FileManager.default.removeItem(at: tempDir)
            throw DownloadError.downloadFailed(errorMessage)
        }

        // Find the downloaded file
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let videoFile = contents.first(where: { $0.pathExtension == "mp4" || $0.pathExtension == "mkv" || $0.pathExtension == "webm" }) else {
            try? FileManager.default.removeItem(at: tempDir)
            throw DownloadError.downloadFailed("Downloaded file not found")
        }

        // Now wait for metadata (should already be done by now since download takes longer)
        let metadata: VideoMetadata
        do {
            metadata = try await metadataTask.value
            // Notify handler with final metadata if not already notified from cache
            if !notifiedFromCache {
                metadataHandler?(metadata)
            }
        } catch {
            // If metadata fetch failed, create minimal metadata from filename
            print("[DownloadService] Metadata fetch failed, using filename: \(error)")
            let filename = videoFile.deletingPathExtension().lastPathComponent
            metadata = VideoMetadata(title: filename, duration: 0, uploader: nil, thumbnailURL: nil)
            if !notifiedFromCache {
                metadataHandler?(metadata)
            }
        }

        return (videoFile, metadata)
    }

    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    // MARK: - Binary Path Resolution (Cached)

    /// Resolves yt-dlp path with caching to avoid repeated FileManager calls
    private func resolveYTDLPPath() throws -> URL {
        // Return cached path if available
        if let cached = cachedYTDLPPath {
            return cached
        }

        let path = try findYTDLPPath()
        cachedYTDLPPath = path
        print("[DownloadService] Cached yt-dlp path: \(path.path)")
        return path
    }

    /// Resolves ffmpeg path with caching to avoid repeated FileManager calls
    private func resolveFFmpegPath() throws -> URL {
        // Return cached path if available
        if let cached = cachedFFmpegPath {
            return cached
        }

        let path = try findFFmpegPath()
        cachedFFmpegPath = path
        print("[DownloadService] Cached ffmpeg path: \(path.path)")
        return path
    }

    private func findYTDLPPath() throws -> URL {
        // Check Application Support first (for updates)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipFinder")
        let updatedPath = appSupport.appendingPathComponent("yt-dlp")

        if FileManager.default.isExecutableFile(atPath: updatedPath.path) {
            print("[DownloadService] Found yt-dlp in Application Support: \(updatedPath.path)")
            return updatedPath
        }

        // Fall back to bundled binary
        if let bundledPath = Bundle.main.url(forResource: "yt-dlp", withExtension: nil) {
            print("[DownloadService] Found bundled yt-dlp: \(bundledPath.path)")
            return bundledPath
        }

        // Development fallback - check Resources folder directly
        let devPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // short-clip-finder
            .appendingPathComponent("Resources/yt-dlp")

        if FileManager.default.isExecutableFile(atPath: devPath.path) {
            print("[DownloadService] Found development yt-dlp: \(devPath.path)")
            return devPath
        }

        print("[DownloadService] ERROR: yt-dlp not found in any location")
        print("[DownloadService] Checked: \(updatedPath.path)")
        print("[DownloadService] Checked bundle: \(Bundle.main.bundlePath)")
        print("[DownloadService] Checked dev: \(devPath.path)")
        throw DownloadError.ytdlpNotFound
    }

    private func findFFmpegPath() throws -> URL {
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

        throw DownloadError.downloadFailed("FFmpeg not found - cannot merge video and audio")
    }

    /// Warm up binary paths on initialization to avoid delays on first use
    func warmUpBinaryPaths() async {
        do {
            _ = try resolveYTDLPPath()
            _ = try resolveFFmpegPath()
            print("[DownloadService] Binary paths warmed up successfully")
        } catch {
            print("[DownloadService] Warning: Failed to warm up binary paths: \(error)")
        }
    }

    private func parseProgress(line: String, progressHandler: @escaping @Sendable (Double, String) -> Void) {
        // Parse: [download]  45.2% of 1.20GiB at 5.43MiB/s ETA 01:45
        if line.contains("[download]") && line.contains("%") {
            let pattern = #"(\d+\.?\d*)%"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line),
               let percent = Double(line[range]) {
                let progress = percent / 100.0

                // Extract status message
                var status = "Downloading..."
                if line.contains("ETA") {
                    if let etaRange = line.range(of: "ETA ") {
                        let eta = String(line[etaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        status = "Downloading... ETA \(eta)"
                    }
                }

                Task { @MainActor in
                    progressHandler(progress, status)
                }
            }
        } else if line.contains("[Merger]") || line.contains("Merging") {
            Task { @MainActor in
                progressHandler(0.95, "Merging audio and video...")
            }
        }
    }
}
