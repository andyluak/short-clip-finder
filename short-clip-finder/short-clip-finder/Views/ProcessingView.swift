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

    private var isFailed: Bool {
        if case .failed = appState.currentPhase { return true }
        return false
    }

    private var failedMessage: String {
        if case .failed(let message) = appState.currentPhase {
            return message
        }
        return "An unknown error occurred"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Show failure state or progress state
            if isFailed {
                failureContent
            } else {
                progressContent
            }

            Spacer()

            // Phase steps at bottom (hide when failed)
            if !isFailed {
                phaseSteps
                    .padding(.bottom, Theme.Spacing.xxl)
            }

            // Cancel/Start Over button
            bottomButton
                .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cfSurface)
    }

    // MARK: - Progress Content

    private var progressContent: some View {
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

                    // Show ETA if we have enough progress
                    if let eta = estimatedTimeRemaining, progress >= 0.05 {
                        Text(eta)
                            .font(Theme.Typography.mono)
                            .foregroundStyle(.tertiary)

                        Text("•")
                            .foregroundStyle(.tertiary)
                    }

                    Text("\(Int(progress * 100))%")
                        .font(Theme.Typography.mono)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 300)
            }
        }
    }

    // MARK: - Failure Content

    private var failureContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.cfError.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.cfError)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Processing Failed")
                    .font(Theme.Typography.displayMedium)
                    .tracking(-0.3)

                Text(failedMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 400)
            }

            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    appState.retryLastOperation()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cfAccent)

                Button("Start Over") {
                    appState.newProject()
                }
                .buttonStyle(.bordered)
            }

            // Help text
            VStack(spacing: Theme.Spacing.xs) {
                Text("Common issues:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 4) {
                    helpItem("Check your internet connection")
                    helpItem("Verify your API key in Settings")
                    helpItem("Try a shorter or different video")
                }
            }
            .padding(.top, Theme.Spacing.md)
        }
    }

    private func helpItem(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Phase Steps

    private var phaseSteps: some View {
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
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Group {
            if !isFailed {
                Button("Cancel Processing") {
                    appState.cancelProcessing()
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
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

    /// Estimated time remaining based on elapsed time and progress
    private var estimatedTimeRemaining: String? {
        guard let startTime = appState.phaseStartTime,
              progress > 0 && progress < 1 else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Calculate ETA based on current speed
        let estimatedTotal = elapsed / progress
        let remaining = estimatedTotal - elapsed

        // Don't show if remaining time is too short or too long
        guard remaining > 2 && remaining < 3600 else {
            return nil
        }

        return formatTimeRemaining(remaining)
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        if totalSeconds < 60 {
            return "~\(totalSeconds)s left"
        } else {
            let minutes = totalSeconds / 60
            let secs = totalSeconds % 60
            if secs == 0 {
                return "~\(minutes)m left"
            } else {
                return "~\(minutes)m \(secs)s left"
            }
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
