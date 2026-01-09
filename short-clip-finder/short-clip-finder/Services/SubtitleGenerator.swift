//
//  SubtitleGenerator.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 09.01.2026.
//

import Foundation

/// Generates ASS subtitle files for FFmpeg burn-in
struct SubtitleGenerator {
    let style: SubtitleStyle
    let format: ExportFormat

    /// Generate ASS subtitle content for a clip
    func generateASS(
        segments: [TranscriptSegment],
        clipStart: TimeInterval,
        clipEnd: TimeInterval
    ) -> String {
        let resolution = resolution(for: format)

        // Filter segments that fall within clip range
        let relevantSegments = segments.filter { segment in
            segment.start < clipEnd && segment.end > clipStart
        }

        // Generate word-by-word subtitle events
        let events = generateWordByWordEvents(
            segments: relevantSegments,
            clipStart: clipStart,
            clipEnd: clipEnd
        )

        return buildASSFile(
            resolution: resolution,
            events: events
        )
    }

    /// Write ASS file to temporary location
    func writeASSFile(
        segments: [TranscriptSegment],
        clipStart: TimeInterval,
        clipEnd: TimeInterval
    ) throws -> URL {
        let content = generateASS(segments: segments, clipStart: clipStart, clipEnd: clipEnd)

        // Use a simpler temp path without special characters
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "subs_\(Int(Date().timeIntervalSince1970)).ass"
        let fileURL = tempDir.appendingPathComponent(filename)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        print("[SubtitleGenerator] Created ASS file at: \(fileURL.path)")
        print("[SubtitleGenerator] Content preview:\n\(String(content.prefix(500)))")

        return fileURL
    }

    // MARK: - Private

    private func resolution(for format: ExportFormat) -> (width: Int, height: Int) {
        switch format {
        case .vertical: return (1080, 1920)
        case .square: return (1080, 1080)
        case .horizontal: return (1920, 1080)
        }
    }

    /// Font size adjusted for resolution
    private func fontSize(for format: ExportFormat) -> Int {
        switch format {
        case .vertical: return 72   // Big and bold for shorts
        case .square: return 64
        case .horizontal: return 48
        }
    }

    /// Bottom margin in pixels
    private func bottomMargin(for format: ExportFormat) -> Int {
        let res = resolution(for: format)
        switch format {
        case .vertical: return Int(Double(res.height) * 0.18)   // 18% from bottom
        case .square: return Int(Double(res.height) * 0.12)
        case .horizontal: return Int(Double(res.height) * 0.08)
        }
    }

    private func generateWordByWordEvents(
        segments: [TranscriptSegment],
        clipStart: TimeInterval,
        clipEnd: TimeInterval
    ) -> [ASSEvent] {
        var events: [ASSEvent] = []

        for segment in segments {
            // If segment has word-level timing, use it
            if !segment.words.isEmpty {
                // Filter words to only those within clip range
                let wordsInClip = segment.words.filter { word in
                    word.end > clipStart && word.start < clipEnd
                }
                events.append(contentsOf: generateChunkedEvents(
                    words: wordsInClip,
                    clipStart: clipStart,
                    clipEnd: clipEnd
                ))
            } else {
                // Fall back to segment-level subtitle
                // Keep original timestamps - FFmpeg with -ss after -i expects original timeline
                let clampedStart = max(clipStart, segment.start)
                let clampedEnd = min(clipEnd, segment.end)

                if clampedEnd > clampedStart {
                    events.append(ASSEvent(
                        start: clampedStart,
                        end: clampedEnd,
                        text: segment.text.uppercased()
                    ))
                }
            }
        }

        return events
    }

    private func generateChunkedEvents(
        words: [TranscriptWord],
        clipStart: TimeInterval,
        clipEnd: TimeInterval
    ) -> [ASSEvent] {
        var events: [ASSEvent] = []
        var currentChunk: [TranscriptWord] = []

        for (index, word) in words.enumerated() {
            let isLastWord = index == words.count - 1
            let nextWord = isLastWord ? nil : words[index + 1]

            currentChunk.append(word)

            // Determine if we should end this chunk
            let shouldEndChunk: Bool = {
                if isLastWord { return true }
                if currentChunk.count >= style.wordsPerChunk { return true }
                if let next = nextWord, next.start - word.end >= style.gapThreshold {
                    return true
                }
                return false
            }()

            if shouldEndChunk && !currentChunk.isEmpty {
                // Generate karaoke-style events for this chunk
                // Each word gets its own event where it's highlighted (bigger, brighter)
                events.append(contentsOf: generateKaraokeEvents(
                    chunk: currentChunk,
                    clipStart: clipStart,
                    clipEnd: clipEnd
                ))
                currentChunk = []
            }
        }

        return events
    }

    /// Generate karaoke-style events where each word is highlighted in turn
    /// Creates overlapping dialogue lines - one per word in the chunk
    private func generateKaraokeEvents(
        chunk: [TranscriptWord],
        clipStart: TimeInterval,
        clipEnd: TimeInterval
    ) -> [ASSEvent] {
        var events: [ASSEvent] = []

        for (activeIndex, activeWord) in chunk.enumerated() {
            // Clamp to clip boundaries
            let wordStart = max(clipStart, activeWord.start)
            let wordEnd = min(clipEnd, activeWord.end)

            guard wordEnd > wordStart else { continue }

            // Build the text with ASS override tags
            // Active word: scale up 108%, full white
            // Inactive words: normal size, slightly dimmed (alpha 40 hex = ~25% transparent)
            var textParts: [String] = []

            for (wordIndex, word) in chunk.enumerated() {
                let wordText = escapeASSText(word.text.uppercased())

                if wordIndex == activeIndex {
                    // Active word: bigger and brighter
                    // \fscx108\fscy108 = scale to 108%
                    // \alpha&H00& = fully opaque
                    textParts.append("{\\fscx108\\fscy108\\alpha&H00&}\(wordText){\\r}")
                } else {
                    // Inactive word: normal size, slightly dimmed
                    // \alpha&H40& = ~25% transparent (hex 40 = 64/255)
                    textParts.append("{\\alpha&H40&}\(wordText){\\r}")
                }
            }

            let fullText = textParts.joined(separator: " ")
            events.append(ASSEvent(start: wordStart, end: wordEnd, text: fullText, isRaw: true))
        }

        return events
    }

    private func buildASSFile(
        resolution: (width: Int, height: Int),
        events: [ASSEvent]
    ) -> String {
        let fontSz = fontSize(for: format)
        let margin = bottomMargin(for: format)
        let outlineSize = max(3, fontSz / 15)  // Proportional outline

        // Use a common system font that FFmpeg can find
        // Arial Bold or Helvetica Bold are good cross-platform choices
        let fontName = "Arial Bold"

        let header = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: \(resolution.width)
        PlayResY: \(resolution.height)
        WrapStyle: 0
        ScaledBorderAndShadow: yes

        """

        // ASS colors are &HAABBGGRR - Alpha, Blue, Green, Red
        // White = &H00FFFFFF (no alpha, full white)
        // Black = &H00000000 (no alpha, full black)
        let styles = """
        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,\(fontName),\(fontSz),&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,\(outlineSize),0,2,20,20,\(margin),1

        """

        let eventsHeader = """
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

        """

        let eventLines = events.map { event in
            // If isRaw, text already contains ASS tags - don't escape
            let displayText = event.isRaw ? event.text : escapeASSText(event.text)
            return "Dialogue: 0,\(formatASSTime(event.start)),\(formatASSTime(event.end)),Default,,0,0,0,,\(displayText)"
        }.joined(separator: "\n")

        return header + styles + eventsHeader + eventLines
    }

    private func formatASSTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let centis = Int((seconds - floor(seconds)) * 100)
        return String(format: "%d:%02d:%02d.%02d", hours, mins, secs, centis)
    }

    private func escapeASSText(_ text: String) -> String {
        // Escape special ASS characters
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\N")
    }
}

// MARK: - ASS Event

private struct ASSEvent {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
    let isRaw: Bool  // If true, text contains ASS tags and shouldn't be escaped

    init(start: TimeInterval, end: TimeInterval, text: String, isRaw: Bool = false) {
        self.start = start
        self.end = end
        self.text = text
        self.isRaw = isRaw
    }
}
