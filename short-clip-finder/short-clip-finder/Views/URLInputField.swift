//
//  URLInputField.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct URLInputField: View {
    @Binding var urlString: String
    let onSubmit: () -> Void

    @State private var validationState: ValidationState = .empty
    @FocusState private var isFocused: Bool

    enum ValidationState {
        case empty
        case valid
        case invalidFormat
        case unsupportedPlatform
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("https://youtube.com/watch?v=...", text: $urlString)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        if validationState == .valid {
                            onSubmit()
                        }
                    }
                    .onChange(of: urlString) { _, newValue in
                        validate(newValue)
                    }

                Button {
                    pasteFromClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .help("Paste from clipboard")
            }

            // Validation message
            if let message = validationMessage {
                HStack(spacing: 4) {
                    Image(systemName: validationIcon)
                    Text(message)
                }
                .font(.caption)
                .foregroundStyle(validationColor)
            }
        }
        .onAppear {
            // Auto-paste if clipboard has a URL
            if urlString.isEmpty {
                checkClipboardForURL()
            }
        }
    }

    private var borderColor: Color {
        switch validationState {
        case .empty:
            return Color.secondary.opacity(0.3)
        case .valid:
            return Color.green.opacity(0.5)
        case .invalidFormat, .unsupportedPlatform:
            return Color.red.opacity(0.5)
        }
    }

    private var validationMessage: String? {
        switch validationState {
        case .empty:
            return nil
        case .valid:
            return "Ready to download"
        case .invalidFormat:
            return "Please enter a valid URL"
        case .unsupportedPlatform:
            return "This platform may not be supported"
        }
    }

    private var validationIcon: String {
        switch validationState {
        case .empty:
            return ""
        case .valid:
            return "checkmark.circle.fill"
        case .invalidFormat:
            return "xmark.circle.fill"
        case .unsupportedPlatform:
            return "exclamationmark.triangle.fill"
        }
    }

    private var validationColor: Color {
        switch validationState {
        case .empty:
            return .secondary
        case .valid:
            return .green
        case .invalidFormat:
            return .red
        case .unsupportedPlatform:
            return .orange
        }
    }

    private func validate(_ urlString: String) {
        if urlString.isEmpty {
            validationState = .empty
            return
        }

        if !DownloadService.isValidURL(urlString) {
            validationState = .invalidFormat
            return
        }

        if !DownloadService.isSupportedPlatform(urlString) {
            validationState = .unsupportedPlatform
            return
        }

        validationState = .valid
    }

    private func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func checkClipboardForURL() {
        if let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           DownloadService.isValidURL(string) {
            urlString = string
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        URLInputField(urlString: .constant(""), onSubmit: {})
        URLInputField(urlString: .constant("https://youtube.com/watch?v=abc123"), onSubmit: {})
        URLInputField(urlString: .constant("not a url"), onSubmit: {})
    }
    .padding()
    .frame(width: 500)
}
