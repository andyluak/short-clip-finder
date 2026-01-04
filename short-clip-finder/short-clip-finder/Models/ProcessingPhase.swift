//
//  ProcessingPhase.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

enum ProcessingPhase: Sendable, Equatable {
    case downloading(progress: Double, status: String)
    case transcribing(progress: Double, status: String = "")
    case analyzing(progress: Double, status: String = "")
    case complete
    case failed(message: String)

    var displayName: String {
        switch self {
        case .downloading: "Downloading"
        case .transcribing: "Transcribing"
        case .analyzing: "Analyzing"
        case .complete: "Complete"
        case .failed: "Failed"
        }
    }

    var statusMessage: String? {
        switch self {
        case .downloading(_, let status):
            return status.isEmpty ? nil : status
        case .transcribing(_, let status):
            return status.isEmpty ? nil : status
        case .analyzing(_, let status):
            return status.isEmpty ? nil : status
        case .complete, .failed:
            return nil
        }
    }

    var progress: Double {
        switch self {
        case .downloading(let p, _), .transcribing(let p, _), .analyzing(let p, _):
            return p
        case .complete:
            return 1.0
        case .failed:
            return 0.0
        }
    }

    var isActive: Bool {
        switch self {
        case .downloading, .transcribing, .analyzing:
            return true
        case .complete, .failed:
            return false
        }
    }

    /// Descriptive message for user feedback based on progress
    var descriptiveStatus: String {
        switch self {
        case .downloading(_, let status):
            return status.isEmpty ? "Preparing download..." : status
        case .transcribing(let progress, let status):
            if !status.isEmpty { return status }
            if progress < 0.1 {
                return "Listening to your video..."
            } else if progress < 0.5 {
                return "Processing audio..."
            } else if progress < 0.9 {
                return "Recognizing speech patterns..."
            } else {
                return "Finalizing transcript..."
            }
        case .analyzing(let progress, let status):
            if !status.isEmpty { return status }
            if progress < 0.2 {
                return "AI is finding viral moments..."
            } else if progress < 0.5 {
                return "Evaluating clip potential..."
            } else if progress < 0.8 {
                return "Scoring engagement factors..."
            } else {
                return "Preparing recommendations..."
            }
        case .complete:
            return "Processing complete!"
        case .failed(let message):
            return message
        }
    }

    /// Estimated total time in seconds for this phase (rough estimates)
    var estimatedTotalSeconds: Double {
        switch self {
        case .downloading: 30
        case .transcribing: 180 // 3 minutes average
        case .analyzing: 60 // 1 minute average
        case .complete, .failed: 0
        }
    }
}
