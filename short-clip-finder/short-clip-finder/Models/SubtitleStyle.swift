//
//  SubtitleStyle.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 09.01.2026.
//

import SwiftUI

struct SubtitleStyle: Codable, Sendable {
    var fontName: String
    var fontSize: CGFloat
    var textColor: CodableColor
    var strokeColor: CodableColor
    var strokeWidth: CGFloat
    var wordsPerChunk: Int
    var gapThreshold: TimeInterval // Gap in seconds to start new chunk

    /// Bottom padding as percentage of video height (0-1)
    var bottomPadding: CGFloat

    static var `default`: SubtitleStyle {
        SubtitleStyle(
            fontName: "Montserrat-Bold",
            fontSize: 44,
            textColor: CodableColor(.white),
            strokeColor: CodableColor(.black),
            strokeWidth: 3,
            wordsPerChunk: 4,
            gapThreshold: 0.3,
            bottomPadding: 0.15
        )
    }

    /// Adjusted style for different export formats
    func adjusted(for format: ExportFormat) -> SubtitleStyle {
        var adjusted = self
        switch format {
        case .vertical:
            adjusted.fontSize = 44
            adjusted.bottomPadding = 0.18
        case .square:
            adjusted.fontSize = 42
            adjusted.bottomPadding = 0.12
        case .horizontal:
            adjusted.fontSize = 37
            adjusted.bottomPadding = 0.10
        }
        return adjusted
    }
}

// MARK: - Codable Color Wrapper

struct CodableColor: Codable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(_ color: Color) {
        // Convert SwiftUI Color to components
        // For simplicity, we'll use NSColor conversion
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.white
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.opacity = Double(nsColor.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Word Chunk for Display

struct SubtitleChunk: Identifiable {
    let id = UUID()
    let words: [TranscriptWord]
    let startTime: TimeInterval
    let endTime: TimeInterval

    var text: String {
        words.map(\.text).joined(separator: " ")
    }

    func contains(time: TimeInterval) -> Bool {
        time >= startTime && time < endTime
    }

    /// Returns index of word being spoken at given time, if any
    func currentWordIndex(at time: TimeInterval) -> Int? {
        words.firstIndex { time >= $0.start && time < $0.end }
    }
}

// MARK: - Chunk Generator

struct SubtitleChunkGenerator {
    let style: SubtitleStyle

    /// Generate display chunks from transcript words
    func generateChunks(from words: [TranscriptWord]) -> [SubtitleChunk] {
        guard !words.isEmpty else { return [] }

        var chunks: [SubtitleChunk] = []
        var currentChunkWords: [TranscriptWord] = []

        for (index, word) in words.enumerated() {
            let isLastWord = index == words.count - 1
            let nextWord = isLastWord ? nil : words[index + 1]

            currentChunkWords.append(word)

            // Determine if we should end this chunk
            let shouldEndChunk: Bool = {
                // Always end on last word
                if isLastWord { return true }

                // End if we hit max words per chunk
                if currentChunkWords.count >= style.wordsPerChunk { return true }

                // End if there's a significant gap to next word
                if let next = nextWord, next.start - word.end >= style.gapThreshold {
                    return true
                }

                return false
            }()

            if shouldEndChunk && !currentChunkWords.isEmpty {
                let chunk = SubtitleChunk(
                    words: currentChunkWords,
                    startTime: currentChunkWords.first!.start,
                    endTime: currentChunkWords.last!.end
                )
                chunks.append(chunk)
                currentChunkWords = []
            }
        }

        return chunks
    }

    /// Get words relevant to a specific time range (for clip preview)
    func generateChunks(from segments: [TranscriptSegment], in timeRange: ClosedRange<TimeInterval>) -> [SubtitleChunk] {
        // Collect all words within the time range
        let relevantWords = segments.flatMap { segment in
            segment.words.filter { word in
                word.start >= timeRange.lowerBound && word.end <= timeRange.upperBound
            }
        }.sorted { $0.start < $1.start }

        return generateChunks(from: relevantWords)
    }
}
