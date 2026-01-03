//
//  ErrorAlertView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ErrorAlertView: View {
    let title: String
    let message: String
    let errorType: ErrorType
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    enum ErrorType {
        case network
        case api
        case fileSystem
        case processing
        case general

        var icon: String {
            switch self {
            case .network:
                "wifi.exclamationmark"
            case .api:
                "key.horizontal"
            case .fileSystem:
                "folder.badge.questionmark"
            case .processing:
                "exclamationmark.triangle"
            case .general:
                "exclamationmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .network:
                .orange
            case .api:
                .red
            case .fileSystem:
                .yellow
            case .processing, .general:
                .red
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: errorType.icon)
                .font(.system(size: 40))
                .foregroundStyle(errorType.color)

            // Title
            Text(title)
                .font(.headline)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)

            // Actions
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)

                if let onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
    }
}

// MARK: - Error Classification Helper

extension ErrorAlertView.ErrorType {
    static func classify(_ error: Error) -> ErrorAlertView.ErrorType {
        let description = error.localizedDescription.lowercased()

        if description.contains("api key") || description.contains("openai") || description.contains("authentication") {
            return .api
        } else if description.contains("network") || description.contains("connection") || description.contains("internet") || description.contains("timeout") {
            return .network
        } else if description.contains("file") || description.contains("directory") || description.contains("permission") || description.contains("disk") {
            return .fileSystem
        } else if description.contains("transcri") || description.contains("analyz") || description.contains("process") {
            return .processing
        } else {
            return .general
        }
    }
}

// MARK: - Error Presentation Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let error = error {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ErrorAlertView(
                            title: error.title,
                            message: error.message,
                            errorType: error.type,
                            onRetry: error.isRetryable ? {
                                self.error = nil
                                onRetry?()
                            } : nil,
                            onDismiss: {
                                self.error = nil
                            }
                        )
                    }
                }
            }
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: ErrorAlertView.ErrorType
    let isRetryable: Bool

    init(title: String, message: String, type: ErrorAlertView.ErrorType, isRetryable: Bool = false) {
        self.title = title
        self.message = message
        self.type = type
        self.isRetryable = isRetryable
    }

    init(from error: Error) {
        let type = ErrorAlertView.ErrorType.classify(error)
        let isRetryable = (error as? RetryableError)?.isRetryable ?? false

        self.title = Self.titleFor(type: type)
        self.message = error.localizedDescription
        self.type = type
        self.isRetryable = isRetryable
    }

    private static func titleFor(type: ErrorAlertView.ErrorType) -> String {
        switch type {
        case .network:
            "Network Error"
        case .api:
            "API Error"
        case .fileSystem:
            "File Error"
        case .processing:
            "Processing Error"
        case .general:
            "Error"
        }
    }
}

extension View {
    func errorAlert(_ error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onRetry: onRetry))
    }
}

#Preview {
    VStack {
        ErrorAlertView(
            title: "Network Error",
            message: "Could not connect to OpenAI servers. Please check your internet connection and try again.",
            errorType: .network,
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )
    }
    .frame(width: 400, height: 400)
}
