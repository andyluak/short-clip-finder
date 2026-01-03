//
//  RetryHelper.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation

enum RetryHelper {
    struct RetryPolicy: Sendable {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double

        nonisolated(unsafe) static let `default` = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )

        nonisolated(unsafe) static let aggressive = RetryPolicy(
            maxAttempts: 5,
            initialDelay: 2.0,
            maxDelay: 60.0,
            backoffMultiplier: 2.0
        )

        nonisolated(unsafe) static let light = RetryPolicy(
            maxAttempts: 2,
            initialDelay: 0.5,
            maxDelay: 5.0,
            backoffMultiplier: 2.0
        )
    }

    /// Execute an async operation with retry logic
    /// - Parameters:
    ///   - policy: The retry policy to use
    ///   - shouldRetry: Closure to determine if an error should trigger a retry
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    static func withRetry<T>(
        policy: RetryPolicy = .default,
        shouldRetry: @escaping (Error) -> Bool,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = policy.initialDelay

        for attempt in 1...policy.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                if !shouldRetry(error) {
                    throw error
                }

                if attempt == policy.maxAttempts {
                    break
                }

                print("[RetryHelper] Attempt \(attempt) failed: \(error.localizedDescription)")
                print("[RetryHelper] Retrying in \(Int(delay))s...")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                delay = min(delay * policy.backoffMultiplier, policy.maxDelay)
            }
        }

        throw lastError ?? RetryError.maxRetriesExceeded
    }

    enum RetryError: LocalizedError {
        case maxRetriesExceeded

        var errorDescription: String? {
            "Operation failed after multiple attempts. Please try again."
        }
    }
}

// MARK: - Retryable Error Protocol

protocol RetryableError {
    var isRetryable: Bool { get }
}

extension AnalysisService.AnalysisError: RetryableError {
    var isRetryable: Bool {
        switch self {
        case .rateLimited:
            true
        case .serverError(let message):
            message.contains("server error") || message.contains("500") || message.contains("502") || message.contains("503")
        case .networkError:
            true
        case .noAPIKey, .invalidAPIKey, .invalidResponse:
            false
        }
    }
}

extension DownloadService.DownloadError: RetryableError {
    var isRetryable: Bool {
        switch self {
        case .downloadFailed(let message):
            message.contains("timeout") || message.contains("connection") || message.contains("network")
        case .metadataFailed:
            true
        case .ytdlpNotFound, .invalidURL, .unsupportedURL, .cancelled:
            false
        }
    }
}
