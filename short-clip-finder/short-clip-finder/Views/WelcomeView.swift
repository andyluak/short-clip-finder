//
//  WelcomeView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @State private var currentStep: OnboardingStep = .welcome
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationError: String?

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case apiKey
        case ready

        var title: String {
            switch self {
            case .welcome: "Welcome to ClipFinder"
            case .apiKey: "Connect OpenAI"
            case .ready: "You're All Set!"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            progressIndicator
                .padding(.top, 20)

            Spacer()

            // Content
            Group {
                switch currentStep {
                case .welcome:
                    welcomeContent
                case .apiKey:
                    apiKeyContent
                case .ready:
                    readyContent
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            // Actions
            actionButtons
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(width: 500, height: 420)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Welcome Content

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to ClipFinder")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Find viral-worthy clips in your long-form videos using AI analysis. Perfect for creating TikToks, Reels, and YouTube Shorts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Features grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                featureItem(icon: "wand.and.stars", title: "AI-Powered", subtitle: "GPT-4o analysis")
                featureItem(icon: "clock", title: "Fast", subtitle: "Local transcription")
                featureItem(icon: "crop", title: "Smart Crop", subtitle: "9:16 auto-framing")
                featureItem(icon: "square.and.arrow.up", title: "Export", subtitle: "Ready for upload")
            }
            .padding(.top, 8)
        }
    }

    private func featureItem(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - API Key Content

    private var apiKeyContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Connect OpenAI")
                .font(.title)
                .fontWeight(.bold)

            Text("ClipFinder uses GPT-4o to analyze your transcripts and find viral moments. You'll need an OpenAI API key.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 320)

            Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                Label("Get your API key", systemImage: "arrow.up.right.square")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Ready Content

    private var readyContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("ClipFinder is ready to help you find viral moments. Start by pasting a YouTube URL or dropping in a video file.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                tipRow(number: 1, text: "Paste any YouTube, Vimeo, or podcast URL")
                tipRow(number: 2, text: "Wait for AI analysis (2-5 minutes)")
                tipRow(number: 3, text: "Select the best clips and export")
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func tipRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            switch currentStep {
            case .welcome:
                Button("Get Started") {
                    withAnimation {
                        currentStep = .apiKey
                    }
                }
                .buttonStyle(.borderedProminent)

            case .apiKey:
                HStack(spacing: 12) {
                    Button("Skip for Now") {
                        withAnimation {
                            currentStep = .ready
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Validate & Continue") {
                        Task {
                            await validateAndContinue()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || isValidating)
                }

            case .ready:
                Button("Start Finding Clips") {
                    markOnboardingComplete()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Actions

    private func validateAndContinue() async {
        isValidating = true
        validationError = nil

        let isValid = await AnalysisService.validateAPIKey(apiKey)

        if isValid {
            do {
                try KeychainManager.save(key: .openAI, value: apiKey)
                withAnimation {
                    currentStep = .ready
                }
            } catch {
                validationError = "Failed to save API key"
            }
        } else {
            validationError = "Invalid API key. Please check and try again."
        }

        isValidating = false
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Onboarding Check

enum OnboardingState {
    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }
}

#Preview {
    WelcomeView(isPresented: .constant(true))
}
