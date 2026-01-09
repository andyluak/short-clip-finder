//
//  ExportSettings.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

struct ExportSettings: Codable, Sendable {
    var format: ExportFormat
    var quality: ExportQuality
    var cropMode: CropMode
    var outputDirectory: URL
    var subtitlesEnabled: Bool
    var subtitleStyle: SubtitleStyle

    static var `default`: ExportSettings {
        ExportSettings(
            format: .vertical,
            quality: .hd1080,
            cropMode: .autoTrack,
            outputDirectory: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ClipFinder Exports"),
            subtitlesEnabled: true,
            subtitleStyle: .default
        )
    }

    /// Load saved settings or return defaults
    static func load() -> ExportSettings {
        guard let data = UserDefaults.standard.data(forKey: "exportSettings"),
              let settings = try? JSONDecoder().decode(ExportSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// Save settings to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "exportSettings")
        }
    }
}

enum ExportFormat: String, Codable, CaseIterable, Sendable {
    case vertical = "9:16"
    case square = "1:1"
    case horizontal = "16:9"

    var displayName: String {
        switch self {
        case .vertical: "9:16 Vertical (TikTok/Reels/Shorts)"
        case .square: "1:1 Square (Instagram)"
        case .horizontal: "16:9 Original"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .vertical: 9.0 / 16.0
        case .square: 1.0
        case .horizontal: 16.0 / 9.0
        }
    }
}

enum ExportQuality: String, Codable, CaseIterable, Sendable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"

    var displayName: String {
        switch self {
        case .hd720: "720p (smaller files)"
        case .hd1080: "1080p (recommended)"
        case .uhd4k: "4K (if source supports)"
        }
    }

    /// Height in pixels (always even for codec compatibility)
    var height: Int {
        switch self {
        case .hd720: 720
        case .hd1080: 1080
        case .uhd4k: 2160
        }
        // All values are already even, but this documents the requirement
    }

    func width(for format: ExportFormat) -> Int {
        let rawWidth: Int
        switch format {
        case .vertical: rawWidth = Int(CGFloat(height) * format.aspectRatio)
        case .square: rawWidth = height
        case .horizontal: rawWidth = Int(CGFloat(height) * format.aspectRatio)
        }
        // Ensure even number (required by libx264)
        return rawWidth - (rawWidth % 2)
    }
}

enum CropMode: String, Codable, CaseIterable, Sendable {
    case autoTrack = "auto"
    case center = "center"

    var displayName: String {
        switch self {
        case .autoTrack: "Auto-detect speaker"
        case .center: "Center crop"
        }
    }
}

/// Represents a clip ready for export
struct ExportJob: Identifiable, Sendable {
    let id: UUID
    let clip: ClipSuggestion
    let videoURL: URL
    let outputURL: URL
    let settings: ExportSettings
}

/// Export progress for a single clip
struct ExportProgress: Sendable {
    let jobId: UUID
    let progress: Double  // 0-1
    let status: ExportStatus
    let outputURL: URL?

    enum ExportStatus: Sendable {
        case pending
        case detectingFaces
        case encoding
        case completed
        case failed(String)
    }
}
