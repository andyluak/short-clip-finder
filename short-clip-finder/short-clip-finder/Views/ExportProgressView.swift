//
//  ExportProgressView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import AppKit

struct ExportProgressView: View {
    let clips: [ClipSuggestion]
    let progressMap: [UUID: ExportProgress]
    let exportedURLs: [URL]
    let isExporting: Bool
    let onCancel: () -> Void
    let onShowInFinder: () -> Void

    private var completedCount: Int {
        progressMap.values.filter {
            if case .completed = $0.status { return true }
            return false
        }.count
    }

    private var hasFailures: Bool {
        progressMap.values.contains {
            if case .failed = $0.status { return true }
            return false
        }
    }

    private var isComplete: Bool {
        !isExporting && completedCount == clips.count && !exportedURLs.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    Text("\(completedCount) clip\(completedCount == 1 ? "" : "s") exported")
                        .font(.headline)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting \(completedCount + 1) of \(clips.count)...")
                        .font(.headline)
                }
                Spacer()
            }

            // Progress list
            VStack(spacing: 8) {
                ForEach(clips) { clip in
                    ExportClipRow(
                        clip: clip,
                        progress: progressMap[clip.id]
                    )
                }
            }

            Divider()

            // Actions
            HStack {
                if isComplete {
                    Button("Show in Finder") {
                        onShowInFinder()
                    }

                    Spacer()

                    Button("Done") {
                        onCancel()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 200)
    }
}

private struct ExportClipRow: View {
    let clip: ClipSuggestion
    let progress: ExportProgress?

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .frame(width: 20)

            // Clip info
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.hookQuote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.callout)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Progress
            if let progress = progress, progress.progress > 0 && progress.progress < 1 {
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let progress = progress {
            switch progress.status {
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            case .detectingFaces:
                Image(systemName: "face.smiling")
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
            case .encoding:
                Image(systemName: "film")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        guard let progress = progress else { return "Waiting..." }

        switch progress.status {
        case .pending: return "Waiting..."
        case .detectingFaces: return "Detecting faces..."
        case .encoding: return "Encoding..."
        case .completed: return "Done"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}
