//
//  EmptyStateView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct EmptyStateView: View {
    let appState: AppState
    @State private var urlText = ""
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("ClipFinder")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Find viral moments in your videos")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    URLInputField(urlString: $urlText) {
                        processURL()
                    }
                    .frame(maxWidth: 500)
                    .accessibilityLabel("Video URL")
                    .accessibilityHint("Paste a YouTube, Vimeo, or podcast URL")

                    Button {
                        processURL()
                    } label: {
                        Label("Find Viral Clips", systemImage: "sparkles")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!DownloadService.isValidURL(urlText))
                    .help("Analyze video and find viral-worthy clips")
                }

                Text("or")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                dropZone
            }
            .padding(.top, 16)

            // Keyboard shortcut hints
            HStack(spacing: 24) {
                shortcutHint("N", label: "New URL")
                shortcutHint("O", label: "Open File")
                shortcutHint(",", label: "Settings")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)

            Spacer()
        }
        .padding(32)
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

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [8])
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .frame(width: 400, height: 120)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Drop video file here")
                        .foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
            .accessibilityLabel("Drop zone for video files")
            .accessibilityHint("Drag and drop a video file to analyze it")
    }

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
