//
//  ProcessingPhase.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

enum ProcessingPhase: Sendable, Equatable {
    case downloading(progress: Double, status: String)
    case transcribing(progress: Double)
    case analyzing(progress: Double)
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
            return status
        default:
            return nil
        }
    }

    var progress: Double {
        switch self {
        case .downloading(let p, _), .transcribing(let p), .analyzing(let p):
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
}
