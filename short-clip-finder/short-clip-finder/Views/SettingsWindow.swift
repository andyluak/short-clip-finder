//
//  SettingsWindow.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct SettingsWindow: View {
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationState: ValidationState = .none
    @State private var showKey = false

    @Environment(\.dismiss) private var dismiss

    enum ValidationState {
        case none
        case valid
        case invalid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // API Keys Section
            VStack(alignment: .leading, spacing: 12) {
                Text("API Keys")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Group {
                            if showKey {
                                TextField("sk-...", text: $apiKey)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            Task {
                                await validateAndSave()
                            }
                        } label: {
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 60)
                            } else {
                                Text("Save")
                                    .frame(width: 60)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty || isValidating)
                    }

                    HStack(spacing: 4) {
                        switch validationState {
                        case .none:
                            EmptyView()
                        case .valid:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API key saved successfully")
                                .foregroundStyle(.green)
                        case .invalid:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Invalid API key")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                }

                Text("Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Storage Section
            StorageManagementView()

            Spacer()

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 450, height: 500)
        .onAppear {
            if let existingKey = KeychainManager.get(key: .openAI) {
                apiKey = existingKey
                validationState = .valid
            }
        }
    }

    private func validateAndSave() async {
        isValidating = true
        validationState = .none

        let isValid = await AnalysisService.validateAPIKey(apiKey)

        if isValid {
            do {
                try KeychainManager.save(key: .openAI, value: apiKey)
                validationState = .valid
            } catch {
                validationState = .invalid
            }
        } else {
            validationState = .invalid
        }

        isValidating = false
    }
}

#Preview {
    SettingsWindow()
}
