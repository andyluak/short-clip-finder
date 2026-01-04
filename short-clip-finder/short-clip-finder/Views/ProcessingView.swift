//
//  ProcessingView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import Combine

struct ProcessingView: View {
    let appState: AppState
    let videoTitle: String

    @State private var phaseStartTime: Date = Date()
    @State private var elapsedTime: TimeInterval = 0
    @State private var previousPhaseIndex: Int = -1

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            PhaseVisualIndicator(phase: appState.currentPhase)

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
                    label: "Downloading",
                    elapsedTime: phaseIndex(appState.currentPhase) == 0 ? elapsedTime : nil
                )

                PhaseRow(
                    phase: .transcribing(progress: 0),
                    currentPhase: appState.currentPhase,
                    label: "Transcribing",
                    elapsedTime: phaseIndex(appState.currentPhase) == 1 ? elapsedTime : nil
                )

                PhaseRow(
                    phase: .analyzing(progress: 0),
                    currentPhase: appState.currentPhase,
                    label: "Analyzing",
                    elapsedTime: phaseIndex(appState.currentPhase) == 2 ? elapsedTime : nil
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
        .onReceive(timer) { _ in
            elapsedTime = Date().timeIntervalSince(phaseStartTime)
        }
        .onChange(of: phaseIndex(appState.currentPhase)) { _, newIndex in
            if newIndex != previousPhaseIndex {
                phaseStartTime = Date()
                elapsedTime = 0
                previousPhaseIndex = newIndex
            }
        }
        .onAppear {
            previousPhaseIndex = phaseIndex(appState.currentPhase)
            phaseStartTime = Date()
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

// MARK: - Phase Visual Indicator

private struct PhaseVisualIndicator: View {
    let phase: ProcessingPhase
    @State private var isAnimating = false

    var body: some View {
        Group {
            switch phase {
            case .downloading:
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce.down, options: .repeating)

            case .transcribing:
                WaveformAnimation()

            case .analyzing:
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)

            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Waveform Animation

private struct WaveformAnimation: View {
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                WaveformBar(
                    animationPhase: animationPhase,
                    barIndex: index
                )
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
            ) {
                animationPhase = 1
            }
        }
    }
}

private struct WaveformBar: View {
    let animationPhase: CGFloat
    let barIndex: Int

    private var height: CGFloat {
        let baseHeight: CGFloat = 20
        let maxHeight: CGFloat = 48
        let offset = CGFloat(barIndex) * 0.2
        let adjustedPhase = (animationPhase + offset).truncatingRemainder(dividingBy: 1.0)
        let wave = sin(adjustedPhase * .pi)
        return baseHeight + (maxHeight - baseHeight) * wave
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 8, height: height)
    }
}

// MARK: - Phase Row

private struct PhaseRow: View {
    let phase: ProcessingPhase
    let currentPhase: ProcessingPhase
    let label: String
    let elapsedTime: TimeInterval?

    @State private var isPulsing = false

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

    private var estimatedTimeRemaining: String? {
        guard isActive,
              let elapsed = elapsedTime,
              currentPhase.progress > 0.05 else { return nil }

        let estimatedTotal = elapsed / currentPhase.progress
        let remaining = max(0, estimatedTotal - elapsed)

        if remaining < 10 {
            return "Almost done..."
        } else if remaining < 60 {
            return "~\(Int(remaining))s remaining"
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "~\(minutes)m \(seconds)s remaining"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                PhaseIndicator(
                    isActive: isActive,
                    isComplete: isComplete,
                    phaseType: phaseType
                )
                .frame(width: 24, height: 24)

                Text(label)
                    .fontWeight(isActive ? .medium : .regular)
                    .foregroundStyle(isActive || isComplete ? .primary : .secondary)

                Spacer()

                if isActive {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if isActive {
                ProgressView(value: progress)
                    .tint(phaseGradient)
                    .animation(.easeInOut(duration: 0.3), value: progress)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentPhase.descriptiveStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 36)
                        .animation(.easeInOut(duration: 0.2), value: currentPhase.descriptiveStatus)

                    if let timeRemaining = estimatedTimeRemaining {
                        Text(timeRemaining)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 36)
                    }
                }
            }
        }
    }

    private var phaseType: PhaseType {
        switch phase {
        case .downloading: .download
        case .transcribing: .transcribe
        case .analyzing: .analyze
        case .complete, .failed: .download
        }
    }

    private var phaseGradient: LinearGradient {
        switch phase {
        case .downloading:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .transcribing:
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        case .analyzing:
            return LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
        case .complete, .failed:
            return LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
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

// MARK: - Phase Indicator

private enum PhaseType {
    case download, transcribe, analyze
}

private struct PhaseIndicator: View {
    let isActive: Bool
    let isComplete: Bool
    let phaseType: PhaseType

    @State private var isPulsing = false

    private var gradient: LinearGradient {
        switch phaseType {
        case .download:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .transcribe:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .analyze:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        ZStack {
            if isComplete {
                Circle()
                    .fill(.green)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
            } else if isActive {
                // Pulsing ring behind
                Circle()
                    .fill(gradient.opacity(0.3))
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)

                // Filled circle with gradient
                Circle()
                    .fill(gradient)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Inactive: empty circle with subtle border
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .onAppear {
            if isActive {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                isPulsing = false
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}
