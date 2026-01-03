//
//  ProcessingView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ProcessingView: View {
    let appState: AppState
    let videoTitle: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, options: .repeating)

            Text("Processing Video")
                .font(.title)
                .fontWeight(.semibold)

            Text(videoTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            VStack(spacing: 16) {
                PhaseRow(
                    phase: .downloading(progress: 0, status: ""),
                    currentPhase: appState.currentPhase,
                    label: "Downloading"
                )

                PhaseRow(
                    phase: .transcribing(progress: 0),
                    currentPhase: appState.currentPhase,
                    label: "Transcribing"
                )

                PhaseRow(
                    phase: .analyzing(progress: 0),
                    currentPhase: appState.currentPhase,
                    label: "Analyzing"
                )
            }
            .frame(maxWidth: 400)

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Button("Cancel") {
                appState.cancelProcessing()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(32)
    }
}

private struct PhaseRow: View {
    let phase: ProcessingPhase
    let currentPhase: ProcessingPhase
    let label: String

    private var isActive: Bool {
        phaseIndex(currentPhase) == phaseIndex(phase)
    }

    private var isComplete: Bool {
        phaseIndex(currentPhase) > phaseIndex(phase)
    }

    private var progress: Double {
        if isComplete { return 1.0 }
        if isActive { return currentPhase.progress }
        return 0.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                ZStack {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if isActive {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 20)

                Text(label)
                    .foregroundStyle(isActive || isComplete ? .primary : .secondary)

                Spacer()

                if isActive {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if isActive {
                ProgressView(value: progress)
                    .tint(.accentColor)

                if let status = currentPhase.statusMessage, !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }
        }
    }

    private func phaseIndex(_ phase: ProcessingPhase) -> Int {
        switch phase {
        case .downloading: 0
        case .transcribing: 1
        case .analyzing: 2
        case .complete: 3
        case .failed: -1
        }
    }
}
