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
        VStack(spacing: 0) {
            Spacer()

            // Central focus: Current phase
            VStack(spacing: Theme.Spacing.xl) {
                PhaseIcon(phase: appState.currentPhase)
                    .frame(width: 80, height: 80)

                Text(phaseTitle)
                    .font(Theme.Typography.displayMedium)
                    .tracking(-0.3)

                Text(videoTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Progress bar
                VStack(spacing: Theme.Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cfSurfaceElevated)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cfAccent)
                                .frame(width: geo.size.width * progress)
                                .animation(Theme.Animation.normal, value: progress)
                        }
                    }
                    .frame(width: 300, height: 4)

                    HStack {
                        Text(phaseStatus)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(Theme.Typography.mono)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 300)
                }
            }

            Spacer()

            // Phase steps at bottom
            HStack(spacing: Theme.Spacing.xl) {
                PhaseStep(
                    number: 1,
                    label: "Download",
                    isComplete: phaseIndex > 0,
                    isActive: phaseIndex == 0
                )

                PhaseConnector(isActive: phaseIndex >= 1)

                PhaseStep(
                    number: 2,
                    label: "Transcribe",
                    isComplete: phaseIndex > 1,
                    isActive: phaseIndex == 1
                )

                PhaseConnector(isActive: phaseIndex >= 2)

                PhaseStep(
                    number: 3,
                    label: "Analyze",
                    isComplete: phaseIndex > 2,
                    isActive: phaseIndex == 2
                )
            }
            .padding(.bottom, Theme.Spacing.xxl)

            // Cancel button
            Button("Cancel Processing") {
                appState.cancelProcessing()
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cfSurface)
    }

    // MARK: - Computed Properties

    private var progress: Double {
        switch appState.currentPhase {
        case .downloading(let progress, _): return progress
        case .transcribing(let progress, _): return progress
        case .analyzing(let progress, _): return progress
        case .complete: return 1.0
        case .failed: return 0
        }
    }

    private var phaseTitle: String {
        switch appState.currentPhase {
        case .downloading: return "Downloading"
        case .transcribing: return "Transcribing"
        case .analyzing: return "Analyzing"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    private var phaseStatus: String {
        switch appState.currentPhase {
        case .downloading(_, let status): return status.isEmpty ? "Fetching video..." : status
        case .transcribing(_, let status): return status.isEmpty ? "Converting speech to text..." : status
        case .analyzing(_, let status): return status.isEmpty ? "Finding viral moments..." : status
        case .complete: return "Ready to export"
        case .failed(let message): return message
        }
    }

    private var phaseIndex: Int {
        switch appState.currentPhase {
        case .downloading: return 0
        case .transcribing: return 1
        case .analyzing: return 2
        case .complete: return 3
        case .failed: return -1
        }
    }
}

// MARK: - Phase Icon

struct PhaseIcon: View {
    let phase: ProcessingPhase
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.cfAccent.opacity(0.2), lineWidth: 4)

            // Progress ring
            Circle()
                .trim(from: 0, to: phase.progress)
                .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Animation.normal, value: phase.progress)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.cfAccent)
                .symbolEffect(.pulse, options: .repeating, value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var iconName: String {
        switch phase {
        case .downloading: return "arrow.down"
        case .transcribing: return "waveform"
        case .analyzing: return "sparkles"
        case .complete: return "checkmark"
        case .failed: return "exclamationmark"
        }
    }
}

#Preview("Processing View") {
    ProcessingView(appState: AppState(), videoTitle: "How to Build a Million Dollar Business")
        .frame(width: 800, height: 600)
}
