//
//  AppState.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import AVFoundation
import CoreMedia

enum AppScreen {
    case empty
    case processing
    case results
}

@Observable
@MainActor
final class AppState {
    var currentScreen: AppScreen = .empty
    var shouldShowFilePicker = false
    var shouldShowSettings = false

    var currentPhase: ProcessingPhase = .transcribing(progress: 0)
    var videoTitle: String = ""
    var videoURL: URL?
    var errorMessage: String?
    var currentError: AppError?
    var lastURLInput: String?

    var transcriptSegments: [TranscriptSegment] = []
    var clipSuggestions: [ClipSuggestion] = []
    var selectedClipIDs: Set<UUID> = []

    // Export state
    var isExporting = false
    var showExportSettings = false
    var showExportProgress = false
    var exportSettings = ExportSettings.load()
    var exportProgressMap: [UUID: ExportProgress] = [:]
    var exportedURLs: [URL] = []

    // Project state
    var currentProject: Project?
    var recentProjects: [ProjectSummary] = []
    var isLoadingProjects = false

    private var downloadService = DownloadService()
    private var transcriptionService = TranscriptionService()
    private var analysisService = AnalysisService()
    private var exportService = ExportService()
    private var processingTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?

    init() {
        Task {
            // Warm up binary paths in background to avoid delays on first download
            await downloadService.warmUpBinaryPaths()
            await loadRecentProjects()
        }
    }

    func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
        }
    }

    func openFilePicker() {
        openMainWindow()
        shouldShowFilePicker = true
    }

    func processVideo(url: URL) {
        videoURL = url
        videoTitle = url.lastPathComponent
        currentScreen = .processing
        errorMessage = nil
        transcriptSegments = []
        clipSuggestions = []
        selectedClipIDs = []

        processingTask = Task {
            do {
                // Load/download Whisper model (WhisperKit caches automatically)
                currentPhase = .downloading(progress: 0, status: "Loading Whisper model...")
                try await transcriptionService.loadModel { [weak self] progress in
                    Task { @MainActor in
                        self?.currentPhase = .downloading(progress: progress, status: "Loading Whisper model...")
                    }
                }

                // Transcribe
                currentPhase = .transcribing(progress: 0)
                let segments = try await transcriptionService.transcribe(videoURL: url) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentPhase = .transcribing(progress: progress)
                    }
                }

                transcriptSegments = segments

                // AI Analysis
                // TODO: OPTIMIZATION - Start GPT analysis early while transcription continues
                // Once we have the first ~2 minutes of transcript segments, we could start
                // sending them to GPT in parallel. This would overlap transcription and analysis,
                // potentially reducing total processing time by 20-30% for longer videos.
                // Implementation would require streaming segments from TranscriptionService
                // and batching them to AnalysisService as they become available.
                currentPhase = .analyzing(progress: 0)
                let videoDuration = try await getVideoDuration(url: url)
                let suggestions = try await analysisService.analyze(
                    segments: segments,
                    videoDuration: videoDuration
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentPhase = .analyzing(progress: progress)
                    }
                }

                clipSuggestions = suggestions
                // Don't auto-select clips - let user choose
                selectedClipIDs = []

                currentPhase = .complete
                currentScreen = .results

                // Auto-save project
                autoSaveProject()

            } catch is CancellationError {
                currentScreen = .empty
            } catch {
                currentPhase = .failed(message: error.localizedDescription)
                errorMessage = error.localizedDescription
                currentError = AppError(from: error)
            }
        }
    }

    func processURL(_ urlString: String) {
        lastURLInput = urlString
        videoTitle = "Loading..."
        currentScreen = .processing
        errorMessage = nil
        transcriptSegments = []
        clipSuggestions = []
        selectedClipIDs = []

        processingTask = Task {
            do {
                // Download video
                currentPhase = .downloading(progress: 0, status: "Fetching video info...")

                let (localURL, metadata) = try await downloadService.download(
                    url: urlString,
                    progressHandler: { [weak self] progress, status in
                        Task { @MainActor in
                            self?.currentPhase = .downloading(progress: progress, status: status)
                        }
                    },
                    metadataHandler: { [weak self] metadata in
                        Task { @MainActor in
                            self?.videoTitle = metadata.title
                        }
                    }
                )

                videoURL = localURL

                // Load Whisper model
                currentPhase = .downloading(progress: 0.95, status: "Loading Whisper model...")
                try await transcriptionService.loadModel { _ in }

                // Transcribe
                currentPhase = .transcribing(progress: 0)
                let segments = try await transcriptionService.transcribe(videoURL: localURL) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentPhase = .transcribing(progress: progress)
                    }
                }

                transcriptSegments = segments

                // AI Analysis
                currentPhase = .analyzing(progress: 0)
                let suggestions = try await analysisService.analyze(
                    segments: segments,
                    videoDuration: metadata.duration
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentPhase = .analyzing(progress: progress)
                    }
                }

                clipSuggestions = suggestions
                // Don't auto-select clips - let user choose
                selectedClipIDs = []

                currentPhase = .complete
                currentScreen = .results

                // Auto-save project
                autoSaveProject()

            } catch is CancellationError {
                currentScreen = .empty
            } catch {
                currentPhase = .failed(message: error.localizedDescription)
                errorMessage = error.localizedDescription
                currentError = AppError(from: error)
            }
        }
    }

    func retryLastOperation() {
        currentError = nil
        errorMessage = nil

        if let url = lastURLInput {
            processURL(url)
        } else if let videoURL = videoURL {
            processVideo(url: videoURL)
        }
    }

    func dismissError() {
        currentError = nil
        if case .failed = currentPhase {
            currentScreen = .empty
        }
    }

    private func getVideoDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        Task {
            await downloadService.cancel()
            await transcriptionService.cancel()
        }
        currentScreen = .empty
    }

    // MARK: - Clip Management

    /// Update clip start and end times (for trim functionality)
    func updateClipTimes(clipID: UUID, start: TimeInterval, end: TimeInterval) {
        if let index = clipSuggestions.firstIndex(where: { $0.id == clipID }) {
            clipSuggestions[index].startTime = start
            clipSuggestions[index].endTime = end
        }
    }

    // MARK: - Export

    var selectedClips: [ClipSuggestion] {
        clipSuggestions.filter { selectedClipIDs.contains($0.id) }
    }

    func startExport() {
        guard let videoURL = videoURL else { return }

        let clipsToExport = selectedClips
        guard !clipsToExport.isEmpty else { return }

        isExporting = true
        showExportProgress = true
        exportProgressMap = [:]
        exportedURLs = []

        // Initialize pending state for all clips
        for clip in clipsToExport {
            exportProgressMap[clip.id] = ExportProgress(
                jobId: clip.id,
                progress: 0,
                status: .pending,
                outputURL: nil
            )
        }

        exportTask = Task {
            do {
                let urls = try await exportService.exportClips(
                    clips: clipsToExport,
                    videoURL: videoURL,
                    settings: exportSettings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.exportProgressMap[progress.jobId] = progress
                        if let url = progress.outputURL {
                            self?.exportedURLs.append(url)
                        }
                    }
                }

                await MainActor.run {
                    self.exportedURLs = urls
                    self.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        Task {
            await exportService.cancel()
        }
        isExporting = false
        showExportProgress = false
    }

    func showExportedInFinder() {
        guard let firstURL = exportedURLs.first else { return }
        NSWorkspace.shared.selectFile(firstURL.path, inFileViewerRootedAtPath: firstURL.deletingLastPathComponent().path)
    }

    func closeExportProgress() {
        showExportProgress = false
        exportProgressMap = [:]
        exportedURLs = []
    }

    // MARK: - Project Management

    /// Load recent projects from disk
    func loadRecentProjects() async {
        isLoadingProjects = true
        do {
            recentProjects = try await ProjectManager.shared.recentProjects()
        } catch {
            print("Failed to load recent projects: \(error)")
            recentProjects = []
        }
        isLoadingProjects = false
    }

    /// Save current session as a project
    func saveCurrentProject() async {
        guard !clipSuggestions.isEmpty else { return }

        var project = currentProject ?? Project(
            title: videoTitle.isEmpty ? "Untitled Project" : videoTitle
        )

        // Update project with current state
        project.sourceURL = videoURL
        project.transcriptSegments = transcriptSegments
        project.clipSuggestions = clipSuggestions
        project.selectedClipIDs = selectedClipIDs
        project.markUpdated()

        // Save to disk
        do {
            try await ProjectManager.shared.save(project, videoURL: videoURL)
            currentProject = project
            await loadRecentProjects()
        } catch {
            errorMessage = "Failed to save project: \(error.localizedDescription)"
        }
    }

    /// Load a project by ID
    func loadProject(_ projectID: UUID) async {
        do {
            let project = try await ProjectManager.shared.load(projectID: projectID)
            currentProject = project
            videoTitle = project.title
            transcriptSegments = project.transcriptSegments
            clipSuggestions = project.clipSuggestions
            selectedClipIDs = project.selectedClipIDs

            // Try to get local video URL
            if let localURL = try await ProjectManager.shared.videoURL(for: project) {
                videoURL = localURL
            } else {
                videoURL = project.sourceURL
            }

            currentScreen = project.hasAnalysis ? .results : .empty
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load project: \(error.localizedDescription)"
        }
    }

    /// Delete a project
    func deleteProject(_ projectID: UUID) async {
        do {
            try await ProjectManager.shared.delete(projectID: projectID)
            await loadRecentProjects()

            // Clear current project if it was deleted
            if currentProject?.id == projectID {
                currentProject = nil
                resetState()
            }
        } catch {
            errorMessage = "Failed to delete project: \(error.localizedDescription)"
        }
    }

    /// Create new project (clear current state)
    func newProject() {
        currentProject = nil
        resetState()
    }

    private func resetState() {
        currentScreen = .empty
        videoTitle = ""
        videoURL = nil
        errorMessage = nil
        transcriptSegments = []
        clipSuggestions = []
        selectedClipIDs = []
        currentPhase = .transcribing(progress: 0)
    }

    /// Auto-save project after processing completes successfully
    private func autoSaveProject() {
        Task {
            await saveCurrentProject()
        }
    }
}
