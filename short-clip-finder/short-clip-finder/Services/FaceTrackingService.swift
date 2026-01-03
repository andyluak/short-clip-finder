//
//  FaceTrackingService.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import Vision
import AVFoundation
import CoreImage

actor FaceTrackingService {
    private var isCancelled = false

    /// Frames per second to sample (e.g., 3 = sample every ~333ms)
    private let sampleRate: Double = 3.0

    enum TrackingError: LocalizedError {
        case videoLoadFailed
        case noVideoTrack
        case frameExtractionFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .videoLoadFailed: "Could not load video file."
            case .noVideoTrack: "No video track found."
            case .frameExtractionFailed: "Failed to extract video frames."
            case .cancelled: "Face tracking was cancelled."
            }
        }
    }

    // MARK: - Public API

    /// Detect faces in a clip time range and generate crop keyframes
    func generateCropTrack(
        videoURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> CropTrack {
        isCancelled = false

        print("[FaceTracking] Starting for \(startTime) -> \(endTime)")

        let asset = AVURLAsset(url: videoURL)

        // Get video dimensions
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first
        guard let track = videoTrack else {
            throw TrackingError.noVideoTrack
        }

        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let videoSize = size.applying(transform)
        let videoWidth = abs(videoSize.width)
        let videoHeight = abs(videoSize.height)

        print("[FaceTracking] Video size: \(videoWidth) x \(videoHeight)")

        // Extract and analyze frames
        let frameDetections = try await extractAndDetectFaces(
            asset: asset,
            startTime: startTime,
            endTime: endTime,
            progressHandler: progressHandler
        )

        if isCancelled { throw TrackingError.cancelled }

        // Apply smoothing and generate keyframes
        let keyframes = generateSmoothedKeyframes(
            from: frameDetections,
            videoWidth: videoWidth,
            videoHeight: videoHeight
        )

        print("[FaceTracking] Generated \(keyframes.count) keyframes")

        return CropTrack(
            keyframes: keyframes,
            videoWidth: videoWidth,
            videoHeight: videoHeight
        )
    }

    func cancel() {
        isCancelled = true
    }

    // MARK: - Frame Extraction & Detection

    private func extractAndDetectFaces(
        asset: AVURLAsset,
        startTime: TimeInterval,
        endTime: TimeInterval,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> [FrameDetection] {
        let duration = endTime - startTime
        let frameInterval = 1.0 / sampleRate
        let frameCount = Int(ceil(duration * sampleRate))

        print("[FaceTracking] Will sample \(frameCount) frames at \(sampleRate) fps")

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var detections: [FrameDetection] = []

        for frameIndex in 0..<frameCount {
            if isCancelled { break }

            let timestamp = startTime + (Double(frameIndex) * frameInterval)
            let cmTime = CMTime(seconds: timestamp, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: cmTime)

                let faces = try await detectFaces(in: cgImage, at: timestamp)
                detections.append(faces)

                let progress = Double(frameIndex + 1) / Double(frameCount)
                await MainActor.run {
                    progressHandler(progress)
                }
            } catch {
                print("[FaceTracking] Frame \(frameIndex) failed: \(error.localizedDescription)")
                // Continue with next frame
            }
        }

        return detections
    }

    private func detectFaces(in image: CGImage, at timestamp: TimeInterval) async throws -> FrameDetection {
        let request = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let faces: [FaceFrame] = (request.results ?? []).map { observation in
            FaceFrame(
                timestamp: timestamp,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }

        return FrameDetection(timestamp: timestamp, faces: faces)
    }

    // MARK: - Smoothing Algorithm

    private func generateSmoothedKeyframes(
        from detections: [FrameDetection],
        videoWidth: CGFloat,
        videoHeight: CGFloat
    ) -> [CropKeyframe] {
        // Extract primary face positions
        var rawPositions: [(timestamp: TimeInterval, x: CGFloat)] = []

        for detection in detections {
            if let face = detection.primaryFace {
                rawPositions.append((detection.timestamp, face.center.x))
            }
        }

        // If no faces detected, return empty (will use center crop)
        guard !rawPositions.isEmpty else {
            print("[FaceTracking] No faces detected, will use center crop")
            return []
        }

        // Apply exponential moving average smoothing
        let smoothedPositions = applyEMASmoothing(positions: rawPositions, alpha: 0.3)

        // Generate keyframes from smoothed positions
        return smoothedPositions.map { timestamp, x in
            let faceCenter = CGPoint(x: x, y: 0.5)  // Y doesn't matter for vertical crop
            return CropKeyframe.centered(
                on: faceCenter,
                at: timestamp,
                videoWidth: videoWidth,
                videoHeight: videoHeight
            )
        }
    }

    /// Exponential Moving Average smoothing to reduce jitter
    /// Alpha: 0.0 = no smoothing, 1.0 = no memory (raw values)
    private func applyEMASmoothing(
        positions: [(timestamp: TimeInterval, x: CGFloat)],
        alpha: CGFloat
    ) -> [(timestamp: TimeInterval, x: CGFloat)] {
        guard !positions.isEmpty else { return [] }

        var smoothed: [(timestamp: TimeInterval, x: CGFloat)] = []
        var emaX = positions[0].x

        for (timestamp, x) in positions {
            emaX = alpha * x + (1 - alpha) * emaX
            smoothed.append((timestamp, emaX))
        }

        return smoothed
    }
}
