//
//  ProjectManager.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import AppKit

/// Manages project persistence, including save/load and recent projects
actor ProjectManager {
    static let shared = ProjectManager()

    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Directory Management

    /// Base directory for all ClipFinder data
    private var appSupportDirectory: URL {
        get throws {
            let url = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("ClipFinder", isDirectory: true)

            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
            return url
        }
    }

    /// Directory containing all projects
    private var projectsDirectory: URL {
        get throws {
            let url = try appSupportDirectory.appendingPathComponent("projects", isDirectory: true)
            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
            return url
        }
    }

    /// Directory for a specific project
    private func projectDirectory(for projectID: UUID) throws -> URL {
        let url = try projectsDirectory.appendingPathComponent(projectID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    // MARK: - Save Project

    /// Save a project to disk
    func save(_ project: Project) async throws {
        let projectDir = try projectDirectory(for: project.id)
        let projectFile = projectDir.appendingPathComponent("project.json")

        // Encode on current actor - Project is Sendable so this is safe
        let encoder = self.jsonEncoder
        let data = try encoder.encode(project)
        try data.write(to: projectFile, options: .atomic)

        // Update the recent projects index
        try await updateRecentProjectsIndex()
    }

    /// Save project with associated video file (optional)
    func save(_ project: Project, videoURL: URL?) async throws {
        var updatedProject = project

        // Copy video to project folder if provided
        if let videoURL = videoURL {
            let projectDir = try projectDirectory(for: project.id)
            let videoFileName = videoURL.lastPathComponent
            let destinationURL = projectDir.appendingPathComponent(videoFileName)

            // Only copy if not already in project folder
            if videoURL.path != destinationURL.path {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: videoURL, to: destinationURL)
            }

            updatedProject.localVideoPath = videoFileName
        }

        try await save(updatedProject)
    }

    // MARK: - Load Project

    /// Load a project by ID
    nonisolated func load(projectID: UUID) async throws -> Project {
        let projectDir = try await projectDirectory(for: projectID)
        let projectFile = projectDir.appendingPathComponent("project.json")

        guard FileManager.default.fileExists(atPath: projectFile.path) else {
            throw ProjectError.notFound
        }

        let data = try Data(contentsOf: projectFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Project.self, from: data)
    }

    /// Get the local video URL for a project
    func videoURL(for project: Project) throws -> URL? {
        guard let localVideoPath = project.localVideoPath else {
            return project.sourceURL
        }

        let projectDir = try projectDirectory(for: project.id)
        let videoURL = projectDir.appendingPathComponent(localVideoPath)

        guard fileManager.fileExists(atPath: videoURL.path) else {
            // Fall back to source URL if local copy not found
            return project.sourceURL
        }

        return videoURL
    }

    // MARK: - Recent Projects

    /// Get list of recent projects (sorted by updatedAt descending)
    func recentProjects(limit: Int = 10) async throws -> [ProjectSummary] {
        let indexFile = try appSupportDirectory.appendingPathComponent("recent_projects.json")

        guard fileManager.fileExists(atPath: indexFile.path) else {
            return []
        }

        let data = try Data(contentsOf: indexFile)
        var summaries = try jsonDecoder.decode([ProjectSummary].self, from: data)

        // Sort by updatedAt descending and limit
        summaries.sort { $0.updatedAt > $1.updatedAt }
        return Array(summaries.prefix(limit))
    }

    /// Rebuild the recent projects index from disk
    private func updateRecentProjectsIndex() async throws {
        let projectsDir = try projectsDirectory
        let indexFile = try appSupportDirectory.appendingPathComponent("recent_projects.json")

        var summaries: [ProjectSummary] = []

        // Scan all project directories
        let contents = try fileManager.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for folderURL in contents {
            let isDirectory = (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }

            let projectFile = folderURL.appendingPathComponent("project.json")
            guard fileManager.fileExists(atPath: projectFile.path) else { continue }

            do {
                let data = try Data(contentsOf: projectFile)
                let project = try decoder.decode(Project.self, from: data)
                let thumbnailPath = folderURL.appendingPathComponent("thumbnail.jpg").path
                let hasThumbnail = fileManager.fileExists(atPath: thumbnailPath)

                let summary = ProjectSummary(
                    id: project.id,
                    title: project.title,
                    createdAt: project.createdAt,
                    updatedAt: project.updatedAt,
                    clipCount: project.clipCount,
                    thumbnailPath: hasThumbnail ? thumbnailPath : nil
                )
                summaries.append(summary)
            } catch {
                // Skip corrupted projects
                continue
            }
        }

        // Sort and save
        summaries.sort { $0.updatedAt > $1.updatedAt }
        let encoder = self.jsonEncoder
        let data = try encoder.encode(summaries)
        try data.write(to: indexFile, options: .atomic)
    }

    // MARK: - Delete Project

    /// Delete a project and all its files
    func delete(projectID: UUID) async throws {
        let projectDir = try projectDirectory(for: projectID)

        if fileManager.fileExists(atPath: projectDir.path) {
            try fileManager.removeItem(at: projectDir)
        }

        // Update index
        try await updateRecentProjectsIndex()
    }

    // MARK: - Thumbnail Management

    /// Generate and save thumbnail for a project
    func saveThumbnail(_ image: NSImage, for projectID: UUID) async throws {
        let projectDir = try projectDirectory(for: projectID)
        let thumbnailURL = projectDir.appendingPathComponent("thumbnail.jpg")

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            throw ProjectError.thumbnailGenerationFailed
        }

        try jpegData.write(to: thumbnailURL, options: .atomic)
    }

    /// Load thumbnail for a project
    func loadThumbnail(for projectID: UUID) async -> NSImage? {
        guard let projectDir = try? projectDirectory(for: projectID) else { return nil }
        let thumbnailURL = projectDir.appendingPathComponent("thumbnail.jpg")

        guard fileManager.fileExists(atPath: thumbnailURL.path) else { return nil }
        return NSImage(contentsOf: thumbnailURL)
    }

    // MARK: - Storage Info

    /// Calculate total storage used by projects
    func totalStorageUsed() async throws -> Int64 {
        let projectsDir = try projectsDirectory
        return try calculateDirectorySize(at: projectsDir)
    }

    private func calculateDirectorySize(at url: URL) throws -> Int64 {
        var totalSize: Int64 = 0

        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: .skipsHiddenFiles
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            if resourceValues.isRegularFile == true {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }

    /// Delete all projects (clear cache)
    func deleteAllProjects() async throws {
        let projectsDir = try projectsDirectory

        if fileManager.fileExists(atPath: projectsDir.path) {
            try fileManager.removeItem(at: projectsDir)
            try fileManager.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        }

        // Clear index
        let indexFile = try appSupportDirectory.appendingPathComponent("recent_projects.json")
        if fileManager.fileExists(atPath: indexFile.path) {
            try fileManager.removeItem(at: indexFile)
        }
    }
}

// MARK: - Errors

enum ProjectError: LocalizedError {
    case notFound
    case saveFailed(Error)
    case loadFailed(Error)
    case thumbnailGenerationFailed
    case directoryCreationFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Project not found"
        case .saveFailed(let error):
            return "Failed to save project: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load project: \(error.localizedDescription)"
        case .thumbnailGenerationFailed:
            return "Failed to generate project thumbnail"
        case .directoryCreationFailed:
            return "Failed to create project directory"
        }
    }
}
