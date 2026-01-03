//
//  VideoMetadata.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

struct VideoMetadata: Sendable, Codable {
    let title: String
    let duration: TimeInterval
    let uploader: String?
    let thumbnailURL: URL?
    let description: String?

    init(
        title: String,
        duration: TimeInterval,
        uploader: String? = nil,
        thumbnailURL: URL? = nil,
        description: String? = nil
    ) {
        self.title = title
        self.duration = duration
        self.uploader = uploader
        self.thumbnailURL = thumbnailURL
        self.description = description
    }
}

// MARK: - yt-dlp JSON Response

struct YTDLPMetadata: Decodable {
    let title: String?
    let fulltitle: String?
    let duration: Double?
    let uploader: String?
    let channel: String?
    let thumbnail: String?
    let description: String?

    func toVideoMetadata() -> VideoMetadata {
        VideoMetadata(
            title: title ?? fulltitle ?? "Untitled",
            duration: duration ?? 0,
            uploader: uploader ?? channel,
            thumbnailURL: thumbnail.flatMap { URL(string: $0) },
            description: description
        )
    }
}
