//
//  AnalysisService.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

actor AnalysisService {
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"

    enum AnalysisError: LocalizedError {
        case noAPIKey
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse
        case rateLimited
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                "No OpenAI API key configured. Please add your API key in Settings."
            case .invalidAPIKey:
                "Invalid OpenAI API key. Please check your API key in Settings."
            case .networkError(let error):
                "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                "Could not parse AI response."
            case .rateLimited:
                "OpenAI rate limit exceeded. Please try again in a moment."
            case .serverError(let message):
                "OpenAI error: \(message)"
            }
        }
    }

    func analyze(
        segments: [TranscriptSegment],
        videoDuration: TimeInterval,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> [ClipSuggestion] {
        guard let apiKey = await MainActor.run(body: { KeychainManager.get(key: .openAI) }) else {
            throw AnalysisError.noAPIKey
        }

        progressHandler(0.1)

        // Extract valid cut points from word-level timestamps (speech pauses)
        let cutPoints = extractCutPoints(from: segments)

        let transcript = buildTranscript(from: segments)
        let prompt = buildPrompt(transcript: transcript, videoDuration: videoDuration)

        progressHandler(0.2)

        // Call GPT with retry logic for transient failures
        let response = try await RetryHelper.withRetry(
            policy: .default,
            shouldRetry: { error in
                if let analysisError = error as? AnalysisError {
                    return analysisError.isRetryable
                }
                return false
            },
            operation: {
                try await self.callGPT(prompt: prompt, apiKey: apiKey)
            }
        )

        progressHandler(0.9)

        let clips = parseResponse(response, videoDuration: videoDuration, cutPoints: cutPoints)

        progressHandler(1.0)

        return clips.sorted { $0.viralityScore > $1.viralityScore }
    }

    // MARK: - Cut Point Detection

    /// Extract valid cut points from word timestamps - places with natural speech pauses
    private nonisolated func extractCutPoints(from segments: [TranscriptSegment]) -> [TimeInterval] {
        var cutPoints: [TimeInterval] = [0] // Always include start
        let minPauseGap: TimeInterval = 0.25 // 250ms pause = natural break

        var allWords: [(start: TimeInterval, end: TimeInterval)] = []

        // Collect all words with timestamps
        for segment in segments {
            for word in segment.words {
                allWords.append((start: word.start, end: word.end))
            }
            // Segment boundaries are always valid cut points
            cutPoints.append(segment.end)
        }

        // Sort words by start time
        allWords.sort { $0.start < $1.start }

        // Find gaps between words (natural pauses)
        for i in 0..<(allWords.count - 1) {
            let currentEnd = allWords[i].end
            let nextStart = allWords[i + 1].start
            let gap = nextStart - currentEnd

            if gap >= minPauseGap {
                // Add the END of current word as cut point (pause starts here)
                cutPoints.append(currentEnd)
            }
        }

        // Sort and deduplicate
        let uniqueCutPoints = Array(Set(cutPoints)).sorted()
        print("[AnalysisService] Found \(uniqueCutPoints.count) valid cut points")
        return uniqueCutPoints
    }

    /// Snap a timestamp to the nearest valid cut point
    private nonisolated func snapToNearestCutPoint(_ time: TimeInterval, cutPoints: [TimeInterval], preferBefore: Bool) -> TimeInterval {
        guard !cutPoints.isEmpty else { return time }

        // Find closest cut point
        var closest = cutPoints[0]
        var closestDistance = abs(time - closest)

        for cutPoint in cutPoints {
            let distance = abs(time - cutPoint)
            if distance < closestDistance {
                closest = cutPoint
                closestDistance = distance
            }
        }

        // If within 2 seconds of original, use the snap point
        // Otherwise, prefer direction based on preferBefore
        if closestDistance <= 2.0 {
            return closest
        }

        // Find best directional match
        if preferBefore {
            // For start times: find latest cut point before or at time
            let beforePoints = cutPoints.filter { $0 <= time + 0.5 }
            return beforePoints.last ?? closest
        } else {
            // For end times: find earliest cut point after or at time
            let afterPoints = cutPoints.filter { $0 >= time - 0.5 }
            return afterPoints.first ?? closest
        }
    }

    private func buildTranscript(from segments: [TranscriptSegment]) -> String {
        segments.map { segment in
            let startTs = formatTimestamp(segment.start)
            let endTs = formatTimestamp(segment.end)
            return "[\(startTs)-\(endTs)] \(segment.text)"
        }.joined(separator: "\n")
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let fraction = time - Double(totalSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, Int(fraction * 10))
        } else {
            return String(format: "%d:%02d.%d", minutes, seconds, Int(fraction * 10))
        }
    }

    private func buildPrompt(transcript: String, videoDuration: TimeInterval) -> String {
        let durationMinutes = Int(videoDuration / 60)
        let expectedClips = max(5, durationMinutes / 5)  // Roughly 1 clip per 5 minutes

        return """
        You are a viral content analyst specializing in short-form video clips for TikTok, YouTube Shorts, and Instagram Reels.

        VIDEO DURATION: \(durationMinutes) minutes (\(Int(videoDuration)) seconds total)
        EXPECTED OUTPUT: Find approximately \(expectedClips)-\(expectedClips + 5) clips

        CRITICAL REQUIREMENTS:
        1. Each clip MUST be between 30-90 seconds long (this is mandatory!)
        2. start_time and end_time are in SECONDS (not timestamps)
        3. Clips should be complete thoughts that work standalone
        4. Align clip start/end with natural speech pauses shown by segment boundaries

        TRANSCRIPT FORMAT:
        - Each line shows [START_TIME-END_TIME] in MM:SS.d format (minutes:seconds.tenths)
        - Example: [1:23.4-1:28.7] means segment starts at 1:23.4 and ends at 1:28.7
        - Use segment END times to determine where to cut clips for clean audio boundaries

        WHAT MAKES A VIRAL CLIP:
        - Strong hook in first 3 seconds (surprising statement, question, bold claim)
        - Emotional peaks (humor, inspiration, controversy, revelation)
        - Quotable moments people would share
        - Educational value or actionable insights
        - Story with beginning, middle, end

        TRANSCRIPT (timestamps in brackets showing start-end):
        \(transcript)

        OUTPUT FORMAT for each clip:
        - virality_score: 0-100 (realistically assess viral potential)
        - hook_quote: The exact opening line that hooks viewers (max 15 words)
        - start_time: Start time in SECONDS (e.g., 125 for 2:05) - align with segment start
        - end_time: End time in SECONDS (must be 30-90 seconds after start_time) - align with segment end
        - reasoning: Why this clip would perform well (1-2 sentences)

        Remember: MINIMUM 30 seconds, MAXIMUM 90 seconds per clip. No exceptions.
        """
    }

    private func callGPT(prompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonSchema: [String: Any] = [
            "name": "clip_suggestions",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "clips": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "virality_score": ["type": "integer"],
                                "hook_quote": ["type": "string"],
                                "start_time": ["type": "number"],
                                "end_time": ["type": "number"],
                                "reasoning": ["type": "string"]
                            ],
                            "required": ["virality_score", "hook_quote", "start_time", "end_time", "reasoning"],
                            "additionalProperties": false
                        ]
                    ]
                ],
                "required": ["clips"],
                "additionalProperties": false
            ]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": jsonSchema
            ],
            "temperature": 0.7,
            "max_tokens": 16384  // Increased for longer podcasts with many clips
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AnalysisError.invalidAPIKey
        case 429:
            throw AnalysisError.rateLimited
        case 400...499:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AnalysisError.serverError(errorBody)
        case 500...599:
            throw AnalysisError.serverError("OpenAI server error. Please try again.")
        default:
            throw AnalysisError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AnalysisError.invalidResponse
        }

        return content
    }

    private nonisolated func parseResponse(_ response: String, videoDuration: TimeInterval, cutPoints: [TimeInterval]) -> [ClipSuggestion] {
        guard let data = response.data(using: .utf8),
              let gptResponse = try? JSONDecoder().decode(GPTClipResponse.self, from: data) else {
            print("[AnalysisService] Failed to parse GPT response")
            return []
        }

        print("[AnalysisService] Parsed \(gptResponse.clips.count) raw clips from GPT")

        // Filter and fix clip durations
        let validClips = gptResponse.clips.compactMap { clip -> ClipSuggestion? in
            var suggestion = clip.toClipSuggestion()
            let originalStart = suggestion.startTime
            let originalEnd = suggestion.endTime

            // SNAP timestamps to nearest speech pauses (cut points)
            var snappedStart = snapToNearestCutPoint(suggestion.startTime, cutPoints: cutPoints, preferBefore: true)
            var snappedEnd = snapToNearestCutPoint(suggestion.endTime, cutPoints: cutPoints, preferBefore: false)

            // Validate and clamp startTime
            if snappedStart < 0 {
                snappedStart = 0
            }

            // Validate and clamp endTime to videoDuration
            if snappedEnd > videoDuration {
                snappedEnd = videoDuration
            }

            // Ensure snapped times make sense (end > start)
            if snappedEnd <= snappedStart {
                snappedEnd = min(snappedStart + 45, videoDuration) // Default 45 second clip
            }

            let duration = snappedEnd - snappedStart

            // Skip clips that are way too short (< 15 seconds)
            if duration < 15 {
                print("[AnalysisService] Skipping clip '\(clip.hookQuote.prefix(30))...' - too short (\(Int(duration))s)")
                return nil
            }

            // Extend clips that are slightly under 30s to reach minimum
            if duration < 30 {
                // Find next cut point after current end to extend naturally
                let extensionPoints = cutPoints.filter { $0 > snappedEnd }
                if let nextCutPoint = extensionPoints.first(where: { ($0 - snappedStart) >= 30 && ($0 - snappedStart) <= 90 }) {
                    snappedEnd = nextCutPoint
                } else {
                    // Fallback: extend to meet minimum
                    snappedEnd = min(snappedStart + 35, videoDuration)
                }
            }

            // Log the snapping adjustments
            if abs(snappedStart - originalStart) > 0.5 || abs(snappedEnd - originalEnd) > 0.5 {
                print("[AnalysisService] Snapped clip '\(clip.hookQuote.prefix(25))...': [\(String(format: "%.1f", originalStart))-\(String(format: "%.1f", originalEnd))] → [\(String(format: "%.1f", snappedStart))-\(String(format: "%.1f", snappedEnd))]")
            }

            suggestion = ClipSuggestion(
                id: suggestion.id,
                viralityScore: suggestion.viralityScore,
                hookQuote: suggestion.hookQuote,
                startTime: snappedStart,
                endTime: snappedEnd,
                reasoning: suggestion.reasoning
            )

            return suggestion
        }

        print("[AnalysisService] Returning \(validClips.count) valid clips")
        return validClips
    }

    static func validateAPIKey(_ key: String) async -> Bool {
        guard !key.isEmpty else { return false }

        do {
            return try await RetryHelper.withRetry(
                policy: .light,
                shouldRetry: { _ in true },
                operation: {
                    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                    request.httpMethod = "GET"
                    request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        return httpResponse.statusCode == 200
                    }
                    return false
                }
            )
        } catch {
            return false
        }
    }
}
