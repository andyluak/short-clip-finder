//
//  TranscriptWord.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

struct TranscriptWord: Identifiable, Sendable, Codable {
    let id: UUID
    let text: String
    let start: TimeInterval
    let end: TimeInterval

    init(id: UUID = UUID(), text: String, start: TimeInterval, end: TimeInterval) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
    }
}

struct TranscriptSegment: Identifiable, Sendable, Codable {
    let id: UUID
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let words: [TranscriptWord]

    init(id: UUID = UUID(), text: String, start: TimeInterval, end: TimeInterval, words: [TranscriptWord]) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.words = words
    }
}
