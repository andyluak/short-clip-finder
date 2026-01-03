//
//  Project.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

/// Represents a saved ClipFinder project/session
struct Project: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date

    // Source video info
    var sourceURL: URL?  // Original URL (YouTube, etc.) or local file path
    var localVideoPath: String?  // Relative path in project folder
    var videoMetadata: VideoMetadata?

    // Analysis results
    var transcriptSegments: [TranscriptSegment]
    var clipSuggestions: [ClipSuggestion]
    var faceDetections: [FrameDetection]

    // User selections
    var selectedClipIDs: Set<UUID>

    // Export history
    var exportedClips: [ExportedClip]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceURL: URL? = nil,
        localVideoPath: String? = nil,
        videoMetadata: VideoMetadata? = nil,
        transcriptSegments: [TranscriptSegment] = [],
        clipSuggestions: [ClipSuggestion] = [],
        faceDetections: [FrameDetection] = [],
        selectedClipIDs: Set<UUID> = [],
        exportedClips: [ExportedClip] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceURL = sourceURL
        self.localVideoPath = localVideoPath
        self.videoMetadata = videoMetadata
        self.transcriptSegments = transcriptSegments
        self.clipSuggestions = clipSuggestions
        self.faceDetections = faceDetections
        self.selectedClipIDs = selectedClipIDs
        self.exportedClips = exportedClips
    }

    // MARK: - Computed Properties

    var clipCount: Int {
        clipSuggestions.count
    }

    var selectedClipCount: Int {
        selectedClipIDs.count
    }

    var hasAnalysis: Bool {
        !clipSuggestions.isEmpty
    }

    var duration: TimeInterval {
        videoMetadata?.duration ?? 0
    }

    // MARK: - Mutations

    mutating func markUpdated() {
        updatedAt = Date()
    }

    mutating func updateClipSuggestions(_ clips: [ClipSuggestion]) {
        clipSuggestions = clips
        selectedClipIDs = Set(clips.map(\.id))
        markUpdated()
    }

    mutating func updateTranscript(_ segments: [TranscriptSegment]) {
        transcriptSegments = segments
        markUpdated()
    }

    mutating func updateFaceDetections(_ detections: [FrameDetection]) {
        faceDetections = detections
        markUpdated()
    }

    mutating func toggleClipSelection(_ clipID: UUID) {
        if selectedClipIDs.contains(clipID) {
            selectedClipIDs.remove(clipID)
        } else {
            selectedClipIDs.insert(clipID)
        }
        markUpdated()
    }

    mutating func recordExport(_ export: ExportedClip) {
        exportedClips.append(export)
        markUpdated()
    }
}

// MARK: - Export Record

struct ExportedClip: Identifiable, Codable, Sendable {
    let id: UUID
    let clipID: UUID  // Reference to ClipSuggestion
    let exportedAt: Date
    let outputPath: String
    let format: ExportFormat
    let quality: ExportQuality

    init(
        id: UUID = UUID(),
        clipID: UUID,
        exportedAt: Date = Date(),
        outputPath: String,
        format: ExportFormat,
        quality: ExportQuality
    ) {
        self.id = id
        self.clipID = clipID
        self.exportedAt = exportedAt
        self.outputPath = outputPath
        self.format = format
        self.quality = quality
    }
}

// MARK: - Project Summary (for Recent Projects list)

struct ProjectSummary: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let clipCount: Int
    let thumbnailPath: String?

    init(from project: Project, thumbnailPath: String? = nil) {
        self.id = project.id
        self.title = project.title
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
        self.clipCount = project.clipCount
        self.thumbnailPath = thumbnailPath
    }

    init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        clipCount: Int,
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.clipCount = clipCount
        self.thumbnailPath = thumbnailPath
    }
}
