//
//  EmptyStateView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct EmptyStateView: View {
    let appState: AppState
    @State private var urlText = ""
    @State private var isTargeted = false

    // Animation states
    @State private var iconOffset: CGFloat = 0
    @State private var headerOpacity: Double = 0
    @State private var inputOpacity: Double = 0
    @State private var dropZoneOpacity: Double = 0
    @State private var recentProjectsOpacity: Double = 0
    @State private var shortcutsOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var buttonHovered = false

    // Brand colors
    private let coralColor = Color(red: 1.0, green: 0.45, blue: 0.4)
    private let tealColor = Color(red: 0.2, green: 0.8, blue: 0.75)
    private let orangeColor = Color(red: 1.0, green: 0.6, blue: 0.3)

    var body: some View {
        ZStack {
            // Subtle radial gradient background
            RadialGradient(
                gradient: Gradient(colors: [
                    coralColor.opacity(0.08),
                    tealColor.opacity(0.05),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)

                    // Floating icon with animation
                    Image(systemName: "film.stack")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [coralColor, tealColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .offset(y: iconOffset)
                        .opacity(headerOpacity)
                        .onAppear {
                            startFloatingAnimation()
                        }

                    Text("ClipFinder")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .opacity(headerOpacity)

                    Text("Find viral moments in your videos")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .opacity(headerOpacity)

                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            URLInputField(urlString: $urlText) {
                                processURL()
                            }
                            .frame(maxWidth: 500)
                            .accessibilityLabel("Video URL")
                            .accessibilityHint("Paste a YouTube, Vimeo, or podcast URL")
                            .opacity(inputOpacity)

                            // Enhanced "Find Viral Clips" button
                            Button {
                                processURL()
                            } label: {
                                Label("Find Viral Clips", systemImage: "sparkles")
                                    .frame(minWidth: 160)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(ProminentGradientButtonStyle(
                                startColor: coralColor,
                                endColor: orangeColor,
                                isHovered: buttonHovered
                            ))
                            .controlSize(.large)
                            .disabled(!DownloadService.isValidURL(urlText))
                            .help("Analyze video and find viral-worthy clips")
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    buttonHovered = hovering
                                }
                            }
                            .opacity(inputOpacity)
                        }

                        Text("or")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                            .opacity(dropZoneOpacity)

                        dropZone
                            .opacity(dropZoneOpacity)
                    }
                    .padding(.top, 16)

                    // Recent Projects Section
                    if !appState.recentProjects.isEmpty {
                        recentProjectsSection
                            .opacity(recentProjectsOpacity)
                    }

                    // Keyboard shortcut hints
                    HStack(spacing: 24) {
                        shortcutHint("N", label: "New URL")
                        shortcutHint("O", label: "Open File")
                        shortcutHint(",", label: "Settings")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
                    .opacity(shortcutsOpacity)

                    Spacer(minLength: 32)
                }
                .padding(32)
            }
        }
        .onAppear {
            startStaggeredAnimation()
        }
        .fileImporter(
            isPresented: Binding(
                get: { appState.shouldShowFilePicker },
                set: { appState.shouldShowFilePicker = $0 }
            ),
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            // Glow effect behind the drop zone
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isTargeted
                    ? coralColor.opacity(0.3)
                    : tealColor.opacity(glowOpacity * 0.15)
                )
                .blur(radius: isTargeted ? 20 : 10)
                .scaleEffect(isTargeted ? 1.05 : pulseScale)

            // Main drop zone
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted
                    ? LinearGradient(colors: [coralColor, orangeColor], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [tealColor.opacity(0.4 * pulseScale), coralColor.opacity(0.3 * pulseScale)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: isTargeted ? [] : [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? coralColor.opacity(0.15) : Color.clear)
                )
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                            .font(.title)
                            .foregroundStyle(
                                isTargeted
                                ? AnyShapeStyle(coralColor)
                                : AnyShapeStyle(.secondary)
                            )
                            .scaleEffect(isTargeted ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)

                        Text(isTargeted ? "Release to analyze" : "Drop video file here")
                            .foregroundStyle(isTargeted ? coralColor : .secondary)
                            .fontWeight(isTargeted ? .medium : .regular)
                    }
                }
                .scaleEffect(isTargeted ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTargeted)
        }
        .frame(width: 400, height: 120)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .accessibilityLabel("Drop zone for video files")
        .accessibilityHint("Drag and drop a video file to analyze it")
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: - Recent Projects Section

    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Projects")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                ForEach(appState.recentProjects.prefix(3)) { project in
                    RecentProjectCard(
                        project: project,
                        coralColor: coralColor,
                        tealColor: tealColor
                    ) {
                        Task {
                            await appState.loadProject(project.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 500)
        .padding(.top, 24)
    }

    // MARK: - Animations

    private func startStaggeredAnimation() {
        // Stagger the fade-in of elements
        withAnimation(.easeOut(duration: 0.5)) {
            headerOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            inputOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            dropZoneOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
            recentProjectsOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
            shortcutsOpacity = 1
        }
    }

    private func startFloatingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            iconOffset = -8
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.03
            glowOpacity = 0.6
        }
    }

    // MARK: - Actions

    private func processURL() {
        guard !urlText.isEmpty, DownloadService.isValidURL(urlText) else { return }
        appState.processURL(urlText)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                processFile(url)
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                Task { @MainActor in
                    processFile(url)
                }
            }
        }
        return true
    }

    private func processFile(_ url: URL) {
        appState.processVideo(url: url)
    }

    private func shortcutHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\u{2318}\(key)")
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Prominent Button Style

struct ProminentGradientButtonStyle: ButtonStyle {
    let startColor: Color
    let endColor: Color
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [startColor, endColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(
                color: startColor.opacity(isHovered ? 0.5 : 0.3),
                radius: isHovered ? 12 : 6,
                x: 0,
                y: isHovered ? 6 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
    }
}

// MARK: - Recent Project Card

struct RecentProjectCard: View {
    let project: ProjectSummary
    let coralColor: Color
    let tealColor: Color
    let action: () -> Void

    @State private var isHovered = false

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: project.updatedAt, relativeTo: Date())
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail or placeholder
                ZStack {
                    if let thumbnailPath = project.thumbnailPath,
                       let image = NSImage(contentsOfFile: thumbnailPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [tealColor.opacity(0.3), coralColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: "film")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Project info
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 4) {
                        Text("\(project.clipCount) clips")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("*")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(formattedDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: 140)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(isHovered ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isHovered
                        ? LinearGradient(colors: [coralColor.opacity(0.5), tealColor.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Open project: \(project.title)")
        .accessibilityHint("\(project.clipCount) clips, last edited \(formattedDate)")
    }
}
