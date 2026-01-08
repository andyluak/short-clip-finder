//
//  TrimPopover.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import AVKit

struct TrimPopover: View {
    let clip: ClipSuggestion
    let videoURL: URL
    let onSave: (TimeInterval, TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var startTime: TimeInterval
    @State private var endTime: TimeInterval
    @State private var player: AVPlayer?
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var dragStartInitialTime: TimeInterval = 0
    @State private var dragEndInitialTime: TimeInterval = 0

    private let minDuration: TimeInterval = 5  // Minimum 5 seconds
    private let maxDuration: TimeInterval = 90  // Maximum 90 seconds
    private let recommendedMaxDuration: TimeInterval = 60

    init(
        clip: ClipSuggestion,
        videoURL: URL,
        onSave: @escaping (TimeInterval, TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.clip = clip
        self.videoURL = videoURL
        self.onSave = onSave
        self.onCancel = onCancel
        self._startTime = State(initialValue: clip.startTime)
        self._endTime = State(initialValue: clip.endTime)
    }

    private var duration: TimeInterval {
        endTime - startTime
    }

    private var isOverRecommended: Bool {
        duration > recommendedMaxDuration
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Trim Clip")
                    .font(.headline)
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Video Preview (9:16 aspect)
            videoPreview
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Timeline scrubber
            timelineScrubber

            // Time info
            timeInfo

            // Duration warning
            if isOverRecommended {
                durationWarning
            }

            // Actions
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Reset") {
                    startTime = clip.startTime
                    endTime = clip.endTime
                }
                .buttonStyle(.bordered)

                Button("Save Trim") {
                    onSave(startTime, endTime)
                }
                .buttonStyle(.borderedProminent)
                .disabled(duration < minDuration)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Video Preview

    private var videoPreview: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)  // Prevent default controls
                    .overlay {
                        // Custom play/pause overlay
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                togglePlayback()
                            }
                    }
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }

    // MARK: - Timeline Scrubber

    // Context window: show ±15 seconds around the clip midpoint
    private var contextStart: TimeInterval {
        max(0, clip.startTime - 15)
    }

    private var contextEnd: TimeInterval {
        clip.endTime + 15
    }

    private var contextDuration: TimeInterval {
        contextEnd - contextStart
    }

    private var timelineScrubber: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let clipStartX = CGFloat((startTime - contextStart) / contextDuration) * totalWidth
            let clipEndX = CGFloat((endTime - contextStart) / contextDuration) * totalWidth

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 40)

                // Selected region
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: max(0, clipEndX - clipStartX), height: 40)
                    .offset(x: clipStartX)

                // Start handle
                trimHandle(isStart: true)
                    .offset(x: clipStartX - 10)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDraggingStart {
                                    dragStartInitialTime = startTime
                                }
                                isDraggingStart = true
                                let delta = Double(value.translation.width / totalWidth) * contextDuration
                                let newStart = dragStartInitialTime + delta
                                startTime = max(contextStart, min(newStart, endTime - minDuration))
                                seekToTime(startTime)
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                            }
                    )

                // End handle
                trimHandle(isStart: false)
                    .offset(x: clipEndX - 10)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDraggingEnd {
                                    dragEndInitialTime = endTime
                                }
                                isDraggingEnd = true
                                let delta = Double(value.translation.width / totalWidth) * contextDuration
                                let newEnd = dragEndInitialTime + delta
                                endTime = max(startTime + minDuration, min(newEnd, min(contextEnd, startTime + maxDuration)))
                                seekToTime(endTime)
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                            }
                    )
            }
        }
        .frame(height: 40)
    }

    private func trimHandle(isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor)
            .frame(width: 20, height: 48)
            .overlay {
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 3, height: 3)
                    }
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

    // MARK: - Time Info

    private var timeInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Start")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatTime(startTime))
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Duration")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatDuration(duration))
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(isOverRecommended ? .orange : .primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("End")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatTime(endTime))
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    // MARK: - Duration Warning

    private var durationWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text("Clips over 60 seconds may not perform as well on short-form platforms")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Player Control

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        seekToTime(startTime)
    }

    private func seekToTime(_ time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if player.rate > 0 {
            player.pause()
        } else {
            seekToTime(startTime)
            player.play()

            // Stop at end time
            let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
            player.addBoundaryTimeObserver(forTimes: [NSValue(time: endCMTime)], queue: .main) { [weak player] in
                player?.pause()
            }
        }
    }

    // MARK: - Formatting

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }
}

#Preview {
    let mockClip = ClipSuggestion(
        viralityScore: 92,
        hookQuote: "Test quote",
        startTime: 120,
        endTime: 165,
        reasoning: "Test reasoning"
    )

    TrimPopover(
        clip: mockClip,
        videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
        onSave: { _, _ in },
        onCancel: { }
    )
}
