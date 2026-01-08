//
//  ClipSuggestion.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

struct ClipSuggestion: Identifiable, Codable, Sendable {
    let id: UUID
    let viralityScore: Int
    let hookQuote: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    let reasoning: String

    var duration: TimeInterval {
        endTime - startTime
    }

    var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }

    var formattedTimeRange: String {
        "\(formatTime(startTime)) → \(formatTime(endTime))"
    }

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

    init(
        id: UUID = UUID(),
        viralityScore: Int,
        hookQuote: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        reasoning: String
    ) {
        self.id = id
        self.viralityScore = viralityScore
        self.hookQuote = hookQuote
        self.startTime = startTime
        self.endTime = endTime
        self.reasoning = reasoning
    }
}

// MARK: - Virality Level

extension ClipSuggestion {
    enum ViralityLevel: String {
        case viral = "VIRAL"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"

        var color: String {
            switch self {
            case .viral: "red"
            case .high: "orange"
            case .medium: "yellow"
            case .low: "gray"
            }
        }
    }

    var viralityLevel: ViralityLevel {
        switch viralityScore {
        case 85...100: .viral
        case 70..<85: .high
        case 50..<70: .medium
        default: .low
        }
    }
}

// MARK: - GPT Response Parsing

struct GPTClipResponse: Codable {
    let clips: [GPTClip]

    struct GPTClip: Codable {
        let viralityScore: Int
        let hookQuote: String
        let startTime: Double
        let endTime: Double
        let reasoning: String

        enum CodingKeys: String, CodingKey {
            case viralityScore = "virality_score"
            case hookQuote = "hook_quote"
            case startTime = "start_time"
            case endTime = "end_time"
            case reasoning
        }

        func toClipSuggestion() -> ClipSuggestion {
            ClipSuggestion(
                viralityScore: viralityScore,
                hookQuote: hookQuote,
                startTime: startTime,
                endTime: endTime,
                reasoning: reasoning
            )
        }
    }
}
