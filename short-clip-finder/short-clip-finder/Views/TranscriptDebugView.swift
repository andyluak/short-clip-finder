//
//  TranscriptDebugView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct TranscriptDebugView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if appState.transcriptSegments.isEmpty {
                emptyState
            } else {
                transcriptList
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transcript")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(appState.videoTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Copy All") {
                let fullText = appState.transcriptSegments
                    .map { "[\(formatTime($0.start))] \($0.text)" }
                    .joined(separator: "\n\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullText, forType: .string)
            }
            .buttonStyle(.bordered)

            Button("New Video") {
                appState.currentScreen = .empty
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.alignleft")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No transcript available")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var transcriptList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(appState.transcriptSegments) { segment in
                    SegmentRow(segment: segment)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct SegmentRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(formatTime(segment.start))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)

            Text(segment.text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
