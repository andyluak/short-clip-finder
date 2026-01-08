//
//  ExpandedVideoPlayer.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 08.01.2026.
//

import SwiftUI
import AVKit

struct ExpandedVideoPlayer: View {
    let clip: ClipSuggestion
    let videoURL: URL
    let onTrimSave: ((TimeInterval, TimeInterval) -> Void)?
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var startTime: TimeInterval
    @State private var endTime: TimeInterval
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isDraggingPlayhead = false

    private let minDuration: TimeInterval = 5
    private let maxDuration: TimeInterval = 90

    init(
        clip: ClipSuggestion,
        videoURL: URL,
        onTrimSave: ((TimeInterval, TimeInterval) -> Void)?,
        onDismiss: @escaping () -> Void
    ) {
        self.clip = clip
        self.videoURL = videoURL
        self.onTrimSave = onTrimSave
        self.onDismiss = onDismiss
        self._startTime = State(initialValue: clip.startTime)
        self._endTime = State(initialValue: clip.endTime)
    }

    private var duration: TimeInterval {
        endTime - startTime
    }

    private var hasChanges: Bool {
        startTime != clip.startTime || endTime != clip.endTime
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            // Video player
            videoPlayerView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            Divider()

            // Timeline and controls
            controlsSection
                .padding(20)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Clip Preview")
                    .font(.headline)
                Text("\"\(clip.hookQuote)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Virality badge
            ViralityBadge(score: clip.viralityScore, level: clip.viralityLevel)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
        }
    }

    // MARK: - Video Player

    private var videoPlayerView: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .allowsHitTesting(false)
            } else {
                ProgressView()
            }

            // Play/pause overlay
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePlayback()
                }

            // Centered play/pause button
            if !isPlaying {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                        .shadow(radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Timeline scrubber
            timelineScrubber

            // Time info row
            HStack {
                // Current time
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatTime(currentTime))
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                // Start time
                VStack(spacing: 2) {
                    Text("Start")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatTime(startTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Duration
                VStack(spacing: 2) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(duration))s")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(duration > 60 ? .orange : .primary)
                }
                .padding(.horizontal, 24)

                // End time
                VStack(spacing: 2) {
                    Text("End")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatTime(endTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        startTime = clip.startTime
                        endTime = clip.endTime
                        seekToTime(startTime)
                    } label: {
                        Text("Reset")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasChanges)

                    Button {
                        onTrimSave?(startTime, endTime)
                        onDismiss()
                    } label: {
                        Text("Save & Close")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Playback controls
            HStack(spacing: 20) {
                Button {
                    seekToTime(startTime)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.borderless)

                Button {
                    seekRelative(-5)
                } label: {
                    Image(systemName: "gobackward.5")
                }
                .buttonStyle(.borderless)

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.borderless)

                Button {
                    seekRelative(5)
                } label: {
                    Image(systemName: "goforward.5")
                }
                .buttonStyle(.borderless)

                Button {
                    seekToTime(endTime)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(.borderless)
            }
            .font(.title3)
        }
    }

    // MARK: - Timeline Scrubber

    private var timelineScrubber: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let contextWindow: TimeInterval = 30 // Show ±15 seconds context
            let midPoint = (startTime + endTime) / 2
            let windowStart = max(0, midPoint - contextWindow / 2)

            let startX = CGFloat((startTime - windowStart) / contextWindow) * totalWidth
            let endX = CGFloat((endTime - windowStart) / contextWindow) * totalWidth
            let playheadX = CGFloat((currentTime - windowStart) / contextWindow) * totalWidth

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 44)

                // Selected region
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: max(0, endX - startX), height: 44)
                    .offset(x: startX)

                // Start handle
                trimHandle(isStart: true)
                    .offset(x: startX - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingStart = true
                                let delta = Double(value.translation.width / totalWidth) * contextWindow
                                let newStart = max(0, min(startTime + delta, endTime - minDuration))
                                startTime = newStart
                                seekToTime(newStart)
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                            }
                    )

                // End handle
                trimHandle(isStart: false)
                    .offset(x: endX - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingEnd = true
                                let delta = Double(value.translation.width / totalWidth) * contextWindow
                                let newEnd = max(startTime + minDuration, min(endTime + delta, startTime + maxDuration))
                                endTime = newEnd
                                seekToTime(newEnd)
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                            }
                    )

                // Playhead
                if currentTime >= windowStart && currentTime <= windowStart + contextWindow {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 3, height: 50)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .offset(x: playheadX - 1.5)
                }
            }
        }
        .frame(height: 50)
    }

    private func trimHandle(isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor)
            .frame(width: 16, height: 50)
            .overlay {
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: 6)
                    }
                }
            }
            .shadow(radius: 3)
    }

    // MARK: - Player Control

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        currentTime = startTime
        seekToTime(startTime)

        // Add time observer
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [self] time in
            let newTime = CMTimeGetSeconds(time)
            if !isDraggingStart && !isDraggingEnd && !isDraggingPlayhead {
                currentTime = newTime

                // Auto-loop at end time
                if newTime >= endTime && isPlaying {
                    seekToTime(startTime)
                }
            }
        }
    }

    private func seekToTime(_ time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    private func seekRelative(_ delta: TimeInterval) {
        let newTime = max(startTime, min(currentTime + delta, endTime))
        seekToTime(newTime)
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            // If at or past end, restart from beginning
            if currentTime >= endTime - 0.1 {
                seekToTime(startTime)
            }
            player.play()
            isPlaying = true
        }
    }

    // MARK: - Formatting

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}

#Preview {
    let mockClip = ClipSuggestion(
        viralityScore: 85,
        hookQuote: "This is going to change everything",
        startTime: 120,
        endTime: 175,
        reasoning: "Strong emotional hook"
    )

    ExpandedVideoPlayer(
        clip: mockClip,
        videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
        onTrimSave: { _, _ in },
        onDismiss: {}
    )
}
