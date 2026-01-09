//
//  ExpandedVideoPlayer.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 08.01.2026.
//

import SwiftUI
import AVKit

// MARK: - Video Player View (NSViewRepresentable)

/// A simple video player view using AVPlayerLayer for reliable rendering
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = PlayerLayerView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? PlayerLayerView {
            view.player = player
        }
    }
}

/// NSView subclass that uses AVPlayerLayer
private class PlayerLayerView: NSView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }

    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        layer = playerLayer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

// MARK: - Expanded Video Player

struct ExpandedVideoPlayer: View {
    let clip: ClipSuggestion
    let videoURL: URL
    let transcriptSegments: [TranscriptSegment]
    let onTrimSave: ((TimeInterval, TimeInterval) -> Void)?
    let onSegmentEdited: ((UUID, String) -> Void)?
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var startTime: TimeInterval
    @State private var endTime: TimeInterval
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isDraggingPlayhead = false

    // Subtitle and format state
    @State private var subtitlesEnabled = true
    @State private var previewFormat: ExportFormat = .vertical
    @State private var subtitleStyle: SubtitleStyle = .default

    // Transcript editing state
    @State private var editedTexts: [UUID: String] = [:]
    @State private var isEditingTranscript = false

    private let minDuration: TimeInterval = 5
    private let maxDuration: TimeInterval = 90

    init(
        clip: ClipSuggestion,
        videoURL: URL,
        transcriptSegments: [TranscriptSegment] = [],
        onTrimSave: ((TimeInterval, TimeInterval) -> Void)?,
        onSegmentEdited: ((UUID, String) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.clip = clip
        self.videoURL = videoURL
        self.transcriptSegments = transcriptSegments
        self.onTrimSave = onTrimSave
        self.onSegmentEdited = onSegmentEdited
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

    /// Segments that fall within the clip time range
    private var clipSegments: [TranscriptSegment] {
        transcriptSegments.filter { segment in
            segment.start < endTime && segment.end > startTime
        }
    }

    /// Current time range for transcript highlighting
    private var currentClipTimeRange: ClosedRange<TimeInterval>? {
        startTime...endTime
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with format switcher
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            // Main content: Video + Transcript sidebar
            HStack(spacing: 0) {
                // Video player with subtitles
                videoPlayerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Transcript sidebar
                if !clipSegments.isEmpty {
                    Divider()
                    transcriptSidebar
                }
            }

            Divider()

            // Timeline and controls
            controlsSection
                .padding(20)
        }
        .frame(minWidth: 900, minHeight: 550)
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
            // Back button
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text("Clip Preview")
                    .font(.headline)
                Text("\"\(clip.hookQuote)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Format picker
            HStack(spacing: 8) {
                Text("Format:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Format", selection: $previewFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }

            Divider()
                .frame(height: 20)

            // Subtitle toggle
            Button {
                subtitlesEnabled.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: subtitlesEnabled ? "captions.bubble.fill" : "captions.bubble")
                    Text("Subtitles")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(subtitlesEnabled ? .accentColor : nil)

            Divider()
                .frame(height: 20)

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
        GeometryReader { geometry in
            ZStack {
                // Video container with format preview
                formatPreviewContainer(in: geometry)

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
    }

    /// Container that shows video with format-specific crop preview
    @ViewBuilder
    private func formatPreviewContainer(in geometry: GeometryProxy) -> some View {
        let containerSize = geometry.size
        let previewSize = calculatePreviewSize(containerSize: containerSize)

        ZStack {
            // Dimmed background (letterbox/pillarbox effect)
            Color.black

            // Video player container
            ZStack {
                if let player {
                    // Use a simpler video rendering approach
                    VideoPlayerView(player: player)
                        .aspectRatio(previewFormat.aspectRatio, contentMode: .fit)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                // Subtitle overlay on top of video
                if subtitlesEnabled && !clipSegments.isEmpty {
                    SubtitleOverlay(
                        segments: clipSegments,
                        currentTime: currentTime,
                        style: subtitleStyle,
                        format: previewFormat
                    )
                }
            }
            .frame(width: previewSize.width, height: previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    /// Calculate preview size based on format and container
    private func calculatePreviewSize(containerSize: CGSize) -> CGSize {
        let aspectRatio = previewFormat.aspectRatio
        let maxWidth = containerSize.width * 0.9
        let maxHeight = containerSize.height * 0.95

        var width: CGFloat
        var height: CGFloat

        if aspectRatio > 1 {
            // Horizontal - width limited
            width = min(maxWidth, maxHeight * aspectRatio)
            height = width / aspectRatio
        } else {
            // Vertical or square - height limited
            height = min(maxHeight, maxWidth / aspectRatio)
            width = height * aspectRatio
        }

        return CGSize(width: width, height: height)
    }

    // MARK: - Transcript Sidebar

    private var transcriptSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                Text("Transcript")
                    .font(.headline)

                Spacer()

                // Edit toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingTranscript.toggle()
                    }
                } label: {
                    Image(systemName: isEditingTranscript ? "checkmark.circle.fill" : "pencil")
                        .foregroundStyle(isEditingTranscript ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help(isEditingTranscript ? "Done editing" : "Edit transcript")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Transcript list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(clipSegments) { segment in
                            TranscriptSegmentEditRow(
                                segment: segment,
                                isHighlighted: isSegmentCurrent(segment),
                                isEditing: isEditingTranscript,
                                editedText: Binding(
                                    get: { editedTexts[segment.id] ?? segment.text },
                                    set: { newValue in
                                        editedTexts[segment.id] = newValue
                                        onSegmentEdited?(segment.id, newValue)
                                    }
                                ),
                                onTap: {
                                    seekToTime(segment.start)
                                }
                            )
                            .id(segment.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: currentTime) { _, _ in
                    scrollToCurrentSegment(proxy: proxy)
                }
            }
        }
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func isSegmentCurrent(_ segment: TranscriptSegment) -> Bool {
        currentTime >= segment.start && currentTime < segment.end
    }

    private func scrollToCurrentSegment(proxy: ScrollViewProxy) {
        if let segment = clipSegments.first(where: { isSegmentCurrent($0) }) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(segment.id, anchor: .center)
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

// MARK: - Transcript Edit Row (for sidebar)

private struct TranscriptSegmentEditRow: View {
    let segment: TranscriptSegment
    let isHighlighted: Bool
    let isEditing: Bool
    @Binding var editedText: String
    let onTap: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Timestamp button
            Button {
                onTap()
            } label: {
                Text(formatTime(segment.start))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isHighlighted ? .primary : .secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 50, alignment: .trailing)

            // Segment text - editable or read-only
            if isEditing {
                TextEditor(text: $editedText)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(minHeight: 32)
                    .focused($isFocused)
            } else {
                Text(editedText)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isHighlighted ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if !isEditing {
                onTap()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    let mockClip = ClipSuggestion(
        viralityScore: 85,
        hookQuote: "This is going to change everything",
        startTime: 0,
        endTime: 10,
        reasoning: "Strong emotional hook"
    )

    let mockSegments = [
        TranscriptSegment(
            text: "This is going to change everything",
            start: 0,
            end: 3,
            words: [
                TranscriptWord(text: "This", start: 0, end: 0.3),
                TranscriptWord(text: "is", start: 0.3, end: 0.5),
                TranscriptWord(text: "going", start: 0.5, end: 0.8),
                TranscriptWord(text: "to", start: 0.8, end: 1.0),
                TranscriptWord(text: "change", start: 1.0, end: 1.5),
                TranscriptWord(text: "everything", start: 1.5, end: 2.5)
            ]
        ),
        TranscriptSegment(
            text: "And here's why that matters",
            start: 3,
            end: 6,
            words: [
                TranscriptWord(text: "And", start: 3.0, end: 3.2),
                TranscriptWord(text: "here's", start: 3.2, end: 3.5),
                TranscriptWord(text: "why", start: 3.5, end: 3.8),
                TranscriptWord(text: "that", start: 3.8, end: 4.0),
                TranscriptWord(text: "matters", start: 4.0, end: 5.0)
            ]
        )
    ]

    ExpandedVideoPlayer(
        clip: mockClip,
        videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
        transcriptSegments: mockSegments,
        onTrimSave: { _, _ in },
        onSegmentEdited: { _, _ in },
        onDismiss: {}
    )
}
