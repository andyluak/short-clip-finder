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
    @State private var isDropTargeted = false
    @State private var hasAPIKey = KeychainManager.hasOpenAIKey

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // API Key Warning Banner
                if !hasAPIKey {
                    APIKeyWarningBanner {
                        appState.shouldShowSettings = true
                    }
                }

                // Settings button in top-right corner
                HStack {
                    Spacer()
                    Button {
                        appState.shouldShowSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                HStack(spacing: 0) {
                // Left: Main action area
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Bold headline
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Find viral clips")
                            .font(Theme.Typography.displayLarge)
                            .tracking(-0.5)

                        Text("Drop a video or paste a URL to discover\nshare-worthy moments.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }

                    Spacer().frame(height: Theme.Spacing.xxl)

                    // URL Input
                    HStack(spacing: Theme.Spacing.md) {
                        TextField("Paste YouTube, Vimeo, or video URL...", text: $urlText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 14)
                            .background(Color.cfSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .strokeBorder(Color.cfBorder, lineWidth: 1)
                            )
                            .onSubmit { processURL() }

                        Button(action: processURL) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 48)
                                .background(Color.cfAccent)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                        }
                        .buttonStyle(.plain)
                        .disabled(!DownloadService.isValidURL(urlText))
                        .opacity(DownloadService.isValidURL(urlText) ? 1 : 0.5)
                    }
                    .frame(maxWidth: 500)

                    Spacer().frame(height: Theme.Spacing.lg)

                    // Keyboard hints
                    HStack(spacing: Theme.Spacing.lg) {
                        KeyboardHint(key: "⌘N", label: "New URL")
                        KeyboardHint(key: "⌘,", label: "Settings")
                        KeyboardHint(key: "⌘O", label: "Open File")
                    }

                    Spacer()
                }
                .padding(.leading, Theme.Spacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: Drop zone + Recent projects
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer()

                    DropZoneView(isTargeted: $isDropTargeted) { url in
                        appState.processVideo(url: url)
                    }
                    .frame(width: 280, height: 200)

                    if !appState.recentProjects.isEmpty {
                        RecentProjectsGrid(
                            projects: Array(appState.recentProjects.prefix(4)),
                            onSelect: { project in
                                Task { await appState.loadProject(project.id) }
                            }
                        )
                        .frame(width: 280)
                    }

                    Spacer()
                }
                .padding(.trailing, Theme.Spacing.xxxl)
                .frame(width: geometry.size.width * 0.4)
            }
            }
        }
        .background(Color.cfSurface)
        .onAppear {
            hasAPIKey = KeychainManager.hasOpenAIKey
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

    // MARK: - Actions

    private func processURL() {
        guard !urlText.isEmpty, DownloadService.isValidURL(urlText) else { return }
        appState.processURL(urlText)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                appState.processVideo(url: url)
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
}

// MARK: - Drop Zone

struct DropZoneView: View {
    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .strokeBorder(
                    isTargeted ? Color.cfAccent : Color.cfBorder,
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(isTargeted ? Color.cfAccent.opacity(0.1) : Color.clear)
                )

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "film.stack")
                    .font(.system(size: 32))
                    .foregroundStyle(isTargeted ? Color.cfAccent : .secondary)

                Text(isTargeted ? "Release to analyze" : "Drop video file")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isTargeted ? Color.cfAccent : .secondary)
            }
        }
        .animation(Theme.Animation.normal, value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .accessibilityLabel("Drop zone for video files")
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                Task { @MainActor in
                    onDrop(url)
                }
            }
        }
        return true
    }
}

// MARK: - Recent Projects Grid

struct RecentProjectsGrid: View {
    let projects: [ProjectSummary]
    let onSelect: (ProjectSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(1)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(projects) { project in
                    RecentProjectRow(project: project) {
                        onSelect(project)
                    }
                }
            }
        }
    }
}

// MARK: - Recent Project Row

struct RecentProjectRow: View {
    let project: ProjectSummary
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.Spacing.md) {
                // Thumbnail
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Color.cfSurfaceElevated)
                    .frame(width: 48, height: 32)
                    .overlay {
                        if let path = project.thumbnailPath,
                           let image = NSImage(contentsOfFile: path) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text("\(project.clipCount) clips")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(isHovered ? Color.cfSurfaceHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - API Key Warning Banner

struct APIKeyWarningBanner: View {
    let onOpenSettings: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.cfWarning)

            Text("OpenAI API key not configured")
                .font(.system(size: 13, weight: .medium))

            Text("—")
                .foregroundStyle(.tertiary)

            Text("Analysis won't work until you add your API key")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onOpenSettings()
            } label: {
                HStack(spacing: 4) {
                    Text("Open Settings")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.cfWarning)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.cfWarning.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.cfWarning.opacity(0.3))
                .frame(height: 1)
        }
    }
}

#Preview("Empty State") {
    EmptyStateView(appState: AppState())
        .frame(width: 800, height: 600)
}
