//
//  CropKeyframe.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import CoreGraphics

/// Represents a crop rectangle at a specific timestamp for 9:16 export
struct CropKeyframe: Sendable, Codable {
    let timestamp: TimeInterval
    let cropRect: CGRect  // Pixel coordinates in source video

    /// Create crop keyframe centered on a face position
    nonisolated static func centered(
        on faceCenter: CGPoint,
        at timestamp: TimeInterval,
        videoWidth: CGFloat,
        videoHeight: CGFloat,
        outputAspectRatio: CGFloat = 9.0 / 16.0  // 9:16 vertical
    ) -> CropKeyframe {
        // Calculate crop dimensions to maintain aspect ratio
        // Use full height, calculate width based on aspect ratio
        let cropHeight = videoHeight
        let cropWidth = cropHeight * outputAspectRatio

        // Center crop on face, but clamp to video bounds
        var cropX = (faceCenter.x * videoWidth) - (cropWidth / 2)
        cropX = max(0, min(cropX, videoWidth - cropWidth))

        let cropRect = CGRect(
            x: cropX,
            y: 0,
            width: cropWidth,
            height: cropHeight
        )

        return CropKeyframe(timestamp: timestamp, cropRect: cropRect)
    }

    /// Create center crop (fallback when no face detected)
    nonisolated static func centerCrop(
        at timestamp: TimeInterval,
        videoWidth: CGFloat,
        videoHeight: CGFloat,
        outputAspectRatio: CGFloat = 9.0 / 16.0
    ) -> CropKeyframe {
        let cropHeight = videoHeight
        let cropWidth = cropHeight * outputAspectRatio
        let cropX = (videoWidth - cropWidth) / 2

        let cropRect = CGRect(
            x: cropX,
            y: 0,
            width: cropWidth,
            height: cropHeight
        )

        return CropKeyframe(timestamp: timestamp, cropRect: cropRect)
    }
}

/// Collection of keyframes for a clip with interpolation support
struct CropTrack: Sendable, Codable {
    let keyframes: [CropKeyframe]
    let videoWidth: CGFloat
    let videoHeight: CGFloat

    /// Get interpolated crop rect at any timestamp
    func cropRect(at timestamp: TimeInterval) -> CGRect {
        guard !keyframes.isEmpty else {
            // Fallback to center crop
            return CropKeyframe.centerCrop(
                at: timestamp,
                videoWidth: videoWidth,
                videoHeight: videoHeight
            ).cropRect
        }

        // Find surrounding keyframes
        guard let nextIndex = keyframes.firstIndex(where: { $0.timestamp >= timestamp }) else {
            return keyframes.last!.cropRect
        }

        if nextIndex == 0 {
            return keyframes.first!.cropRect
        }

        let prev = keyframes[nextIndex - 1]
        let next = keyframes[nextIndex]

        // Linear interpolation
        let t = (timestamp - prev.timestamp) / (next.timestamp - prev.timestamp)
        return interpolate(from: prev.cropRect, to: next.cropRect, t: t)
    }

    private func interpolate(from: CGRect, to: CGRect, t: TimeInterval) -> CGRect {
        let clampedT = max(0, min(1, t))
        return CGRect(
            x: from.minX + (to.minX - from.minX) * clampedT,
            y: from.minY + (to.minY - from.minY) * clampedT,
            width: from.width + (to.width - from.width) * clampedT,
            height: from.height + (to.height - from.height) * clampedT
        )
    }

    /// Generate FFmpeg crop filter expression for a given aspect ratio
    /// Returns format: "crop=w:h:x:y"
    func ffmpegCropFilter(for format: ExportFormat) -> String {
        let aspectRatio = format.aspectRatio  // width/height

        var w: Int
        var h: Int

        if aspectRatio < 1 {
            // Vertical format (9:16) - width limited
            h = Int(videoHeight)
            w = Int(videoHeight * aspectRatio)
        } else if aspectRatio > 1 {
            // Horizontal format (16:9) - shouldn't need crop usually
            w = Int(videoWidth)
            h = Int(videoWidth / aspectRatio)
        } else {
            // Square (1:1)
            let size = min(videoWidth, videoHeight)
            w = Int(size)
            h = Int(size)
        }

        // Ensure even dimensions (required by libx264)
        w = w - (w % 2)
        h = h - (h % 2)

        // Ensure crop doesn't exceed video bounds
        if CGFloat(w) > videoWidth {
            w = Int(videoWidth) - (Int(videoWidth) % 2)
            h = Int(CGFloat(w) / aspectRatio)
            h = h - (h % 2)
        }
        if CGFloat(h) > videoHeight {
            h = Int(videoHeight) - (Int(videoHeight) % 2)
            w = Int(CGFloat(h) * aspectRatio)
            w = w - (w % 2)
        }

        // Calculate X position (face tracking or center)
        var x: Int
        if keyframes.isEmpty {
            // Center crop
            x = Int((videoWidth - CGFloat(w)) / 2)
        } else {
            // Use average face position from keyframes
            let avgX = keyframes.reduce(0.0) { $0 + $1.cropRect.minX } / CGFloat(keyframes.count)
            x = Int(avgX)
            print("[CropTrack] Using face-tracked X position: \(x) from \(keyframes.count) keyframes")
        }

        // Calculate Y position (center vertically)
        let y = Int((videoHeight - CGFloat(h)) / 2)

        // Clamp to valid range
        x = max(0, min(x, Int(videoWidth) - w))
        let clampedY = max(0, min(y, Int(videoHeight) - h))

        print("[CropTrack] Crop: \(w)x\(h) at (\(x), \(clampedY)) for \(format.rawValue) format")

        return "crop=\(w):\(h):\(x):\(clampedY)"
    }

    /// Legacy method - defaults to vertical
    func ffmpegCropFilter() -> String {
        ffmpegCropFilter(for: .vertical)
    }
}
