//
//  FaceFrame.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import CoreGraphics

/// Represents a detected face at a specific timestamp
struct FaceFrame: Sendable, Codable {
    let timestamp: TimeInterval
    let boundingBox: CGRect  // Normalized 0-1 coordinates (Vision framework format)
    let confidence: Float

    /// Center point of the face (normalized 0-1)
    nonisolated var center: CGPoint {
        CGPoint(
            x: boundingBox.midX,
            y: boundingBox.midY
        )
    }

    /// Convert normalized coordinates to pixel coordinates
    nonisolated func pixelRect(videoWidth: CGFloat, videoHeight: CGFloat) -> CGRect {
        // Vision uses bottom-left origin, convert to top-left
        CGRect(
            x: boundingBox.minX * videoWidth,
            y: (1 - boundingBox.maxY) * videoHeight,
            width: boundingBox.width * videoWidth,
            height: boundingBox.height * videoHeight
        )
    }
}

/// Represents all faces detected in a single frame
struct FrameDetection: Sendable, Codable {
    let timestamp: TimeInterval
    let faces: [FaceFrame]

    /// Returns the primary face (largest by area)
    nonisolated var primaryFace: FaceFrame? {
        faces.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }
    }

    /// Returns true if multiple faces detected
    nonisolated var hasMultipleFaces: Bool {
        faces.count > 1
    }
}
