//
//  SubtitleOverlay.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 09.01.2026.
//

import SwiftUI

/// Subtitle overlay that shows word-by-word captions with stable chunks
/// Chunks stay visible until complete, then transition to next chunk
struct SubtitleOverlay: View {
    let segments: [TranscriptSegment]
    let currentTime: TimeInterval
    let style: SubtitleStyle
    let format: ExportFormat

    /// Pre-computed chunks from segments
    private var chunks: [DisplayChunk] {
        generateChunks(from: segments)
    }

    /// Current chunk to display (stays stable until chunk ends)
    private var currentChunk: DisplayChunk? {
        chunks.first { currentTime >= $0.startTime && currentTime < $0.endTime }
    }

    /// Current word index within the chunk
    private var currentWordIndex: Int? {
        guard let chunk = currentChunk else { return nil }
        return chunk.words.firstIndex { currentTime >= $0.start && currentTime < $0.end }
    }

    var body: some View {
        GeometryReader { geometry in
            let scaledStyle = style.scaledForPreview(containerHeight: geometry.size.height, format: format)

            VStack {
                Spacer()

                if let chunk = currentChunk {
                    chunkView(chunk, style: scaledStyle)
                        .id(chunk.id) // Only changes when chunk changes, not every word
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Spacer()
                    .frame(height: geometry.size.height * scaledStyle.bottomPadding)
            }
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.12), value: currentChunk?.id)
        }
    }

    @ViewBuilder
    private func chunkView(_ chunk: DisplayChunk, style: SubtitleStyle) -> some View {
        HStack(spacing: style.fontSize * 0.2) {
            ForEach(Array(chunk.words.enumerated()), id: \.element.id) { index, word in
                wordView(word.text, isActive: index == currentWordIndex, style: style)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func wordView(_ text: String, isActive: Bool, style: SubtitleStyle) -> some View {
        Text(text)
            .font(.system(size: style.fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.85))
            // Stroke effect using shadows
            .shadow(color: .black, radius: 0, x: style.strokeWidth, y: 0)
            .shadow(color: .black, radius: 0, x: -style.strokeWidth, y: 0)
            .shadow(color: .black, radius: 0, x: 0, y: style.strokeWidth)
            .shadow(color: .black, radius: 0, x: 0, y: -style.strokeWidth)
            .shadow(color: .black, radius: 0, x: style.strokeWidth * 0.7, y: style.strokeWidth * 0.7)
            .shadow(color: .black, radius: 0, x: -style.strokeWidth * 0.7, y: -style.strokeWidth * 0.7)
            .shadow(color: .black, radius: 0, x: style.strokeWidth * 0.7, y: -style.strokeWidth * 0.7)
            .shadow(color: .black, radius: 0, x: -style.strokeWidth * 0.7, y: style.strokeWidth * 0.7)
            .scaleEffect(isActive ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.08), value: isActive)
    }

    // MARK: - Chunk Generation

    private func generateChunks(from segments: [TranscriptSegment]) -> [DisplayChunk] {
        var allChunks: [DisplayChunk] = []

        for segment in segments {
            guard !segment.words.isEmpty else {
                // No word-level timing, use full segment
                // Use segment.id as word.id for stability (no new random UUID)
                allChunks.append(DisplayChunk(
                    words: [TranscriptWord(id: segment.id, text: segment.text, start: segment.start, end: segment.end)],
                    startTime: segment.start,
                    endTime: segment.end
                ))
                continue
            }

            // Group words into stable chunks
            var currentWords: [TranscriptWord] = []

            for (index, word) in segment.words.enumerated() {
                currentWords.append(word)

                let isLastWord = index == segment.words.count - 1
                let nextWord = isLastWord ? nil : segment.words[index + 1]

                // End chunk conditions
                let shouldEndChunk: Bool = {
                    if isLastWord { return true }
                    if currentWords.count >= style.wordsPerChunk { return true }
                    if let next = nextWord, next.start - word.end >= style.gapThreshold {
                        return true
                    }
                    return false
                }()

                if shouldEndChunk && !currentWords.isEmpty {
                    allChunks.append(DisplayChunk(
                        words: currentWords,
                        startTime: currentWords.first!.start,
                        endTime: currentWords.last!.end
                    ))
                    currentWords = []
                }
            }
        }

        return allChunks
    }
}

// MARK: - Display Chunk

private struct DisplayChunk: Identifiable, Equatable {
    // Use deterministic ID based on start time to prevent regeneration on every render
    let id: String
    let words: [TranscriptWord]
    let startTime: TimeInterval
    let endTime: TimeInterval

    init(words: [TranscriptWord], startTime: TimeInterval, endTime: TimeInterval) {
        // Create stable ID from start time - same words at same time = same ID
        self.id = String(format: "chunk_%.3f", startTime)
        self.words = words
        self.startTime = startTime
        self.endTime = endTime
    }

    static func == (lhs: DisplayChunk, rhs: DisplayChunk) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SubtitleStyle Preview Scaling

extension SubtitleStyle {
    /// Scale style for preview (smaller than export)
    func scaledForPreview(containerHeight: CGFloat, format: ExportFormat) -> SubtitleStyle {
        // Base the font size on container height
        // For a 400px tall preview, we want ~24px font
        // For export (1920px for vertical), we want 44px
        let scaleFactor = containerHeight / 1920.0
        let previewFontSize = max(18, min(32, fontSize * scaleFactor * 2.5))

        var scaled = self
        scaled.fontSize = previewFontSize
        scaled.strokeWidth = max(1.5, strokeWidth * scaleFactor * 2)

        // Adjust bottom padding per format
        switch format {
        case .vertical:
            scaled.bottomPadding = 0.15
        case .square:
            scaled.bottomPadding = 0.12
        case .horizontal:
            scaled.bottomPadding = 0.10
        }

        return scaled
    }
}

#Preview {
    ZStack {
        Color.gray

        SubtitleOverlay(
            segments: [
                TranscriptSegment(
                    text: "This is the key moment everyone",
                    start: 0,
                    end: 4,
                    words: [
                        TranscriptWord(text: "This", start: 0, end: 0.4),
                        TranscriptWord(text: "is", start: 0.4, end: 0.6),
                        TranscriptWord(text: "the", start: 0.6, end: 0.8),
                        TranscriptWord(text: "key", start: 0.8, end: 1.2),
                        TranscriptWord(text: "moment", start: 1.5, end: 2.0),
                        TranscriptWord(text: "everyone", start: 2.0, end: 3.0)
                    ]
                )
            ],
            currentTime: 1.0,
            style: .default,
            format: .vertical
        )
    }
    .frame(width: 350, height: 600)
}
