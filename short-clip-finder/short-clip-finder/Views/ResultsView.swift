//
//  ResultsView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ResultsView: View {
    let appState: AppState
    let videoTitle: String
    let videoURL: URL
    let clips: [ClipSuggestion]

    @Binding var selectedClipIDs: Set<UUID>

    // Keyboard navigation state
    @State private var focusedClipIndex: Int = 0
    @FocusState private var isListFocused: Bool

    /// Currently focused clip (for keyboard navigation)
    private var focusedClip: ClipSuggestion? {
        guard !clips.isEmpty, focusedClipIndex >= 0, focusedClipIndex < clips.count else { return nil }
        return clips[focusedClipIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            // Clip list
            if clips.isEmpty {
                emptyState
            } else {
                clipList
            }

            Divider()

            // Footer
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .sheet(isPresented: Binding(
            get: { appState.showExportSettings },
            set: { appState.showExportSettings = $0 }
        )) {
            ExportSettingsPanel(
                settings: Binding(
                    get: { appState.exportSettings },
                    set: { appState.exportSettings = $0 }
                ),
                isPresented: Binding(
                    get: { appState.showExportSettings },
                    set: { appState.showExportSettings = $0 }
                ),
                clipCount: selectedClipIDs.count,
                onExport: {
                    appState.startExport()
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { appState.showExportProgress },
            set: { appState.showExportProgress = $0 }
        )) {
            ExportProgressView(
                clips: appState.selectedClips,
                progressMap: appState.exportProgressMap,
                exportedURLs: appState.exportedURLs,
                isExporting: appState.isExporting,
                onCancel: {
                    if appState.isExporting {
                        appState.cancelExport()
                    } else {
                        appState.closeExportProgress()
                    }
                },
                onShowInFinder: {
                    appState.showExportedInFinder()
                }
            )
        }
        // Keyboard shortcuts
        .focused($isListFocused)
        .onAppear {
            isListFocused = true
        }
        .onKeyPress(.upArrow) {
            navigateClip(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateClip(direction: 1)
            return .handled
        }
        .onKeyPress(.space) {
            // Space toggles export for focused clip
            toggleFocusedClipExport()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "eE")) { _ in
            toggleFocusedClipExport()
            return .handled
        }
        // ⌘↵ to export - handled via hidden button below
        .background {
            Button("Export") {
                if !selectedClipIDs.isEmpty {
                    appState.showExportSettings = true
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .opacity(0)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Keyboard Navigation

    private func navigateClip(direction: Int) {
        guard !clips.isEmpty else { return }
        let newIndex = focusedClipIndex + direction
        focusedClipIndex = max(0, min(newIndex, clips.count - 1))
    }

    private func toggleFocusedClipExport() {
        guard let clip = focusedClip else { return }
        if selectedClipIDs.contains(clip.id) {
            selectedClipIDs.remove(clip.id)
        } else {
            selectedClipIDs.insert(clip.id)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(videoTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(clips.count) clips found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if selectedClipIDs.count == clips.count {
                    selectedClipIDs.removeAll()
                } else {
                    selectedClipIDs = Set(clips.map(\.id))
                }
            } label: {
                if selectedClipIDs.count == clips.count {
                    Text("Deselect All")
                } else {
                    Text("Select All \(clips.count)")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        ClipCardView(
                            clip: clip,
                            videoURL: videoURL,
                            isSelected: Binding(
                                get: { selectedClipIDs.contains(clip.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedClipIDs.insert(clip.id)
                                    } else {
                                        selectedClipIDs.remove(clip.id)
                                    }
                                }
                            ),
                            isFocused: index == focusedClipIndex
                        )
                        .id(clip.id)
                        .onTapGesture {
                            focusedClipIndex = index
                        }
                    }
                }
                .padding(20)
            }
            .onChange(of: focusedClipIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < clips.count {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(clips[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No clips found")
                .font(.headline)

            Text("The AI couldn't identify any viral-worthy moments in this video.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack {
            let selectedClips = clips.filter { selectedClipIDs.contains($0.id) }
            let totalDuration = selectedClips.reduce(0) { $0 + $1.duration }

            Text("Selected: \(selectedClips.count) clips")
                .foregroundStyle(.secondary)

            Text("•")
                .foregroundStyle(.secondary)

            Text("Total: \(formatDuration(totalDuration))")
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                appState.showExportSettings = true
            } label: {
                Label("Export Selected", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedClipIDs.isEmpty)
            .help("Export selected clips (⌘↵)")
            .accessibilityHint("Opens export settings for \(selectedClipIDs.count) selected clips")
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", secs))"
        } else {
            return "\(secs)s"
        }
    }
}

// Preview disabled - requires AppState
// #Preview {
//     ResultsView(...)
// }
