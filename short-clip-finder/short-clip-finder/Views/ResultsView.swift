//
//  ResultsView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

enum ClipSortOrder: String, CaseIterable {
    case virality = "Virality"
    case time = "Time"
}

enum ViralityFilter: String, CaseIterable {
    case all = "All"
    case above70 = "70+"
    case above85 = "85+"

    var minScore: Int {
        switch self {
        case .all: return 0
        case .above70: return 70
        case .above85: return 85
        }
    }
}

struct ResultsView: View {
    let appState: AppState
    let videoTitle: String
    let videoURL: URL
    let clips: [ClipSuggestion]

    @Binding var selectedClipIDs: Set<UUID>

    // Keyboard navigation state
    @State private var focusedClipIndex: Int = 0
    @FocusState private var isListFocused: Bool

    // Sort and filter state
    @State private var sortOrder: ClipSortOrder = .virality
    @State private var viralityFilter: ViralityFilter = .all

    /// Filtered and sorted clips based on current settings
    private var displayedClips: [ClipSuggestion] {
        let filtered = clips.filter { $0.viralityScore >= viralityFilter.minScore }
        switch sortOrder {
        case .virality:
            return filtered.sorted { $0.viralityScore > $1.viralityScore }
        case .time:
            return filtered.sorted { $0.startTime < $1.startTime }
        }
    }

    /// Currently focused clip (for keyboard navigation)
    private var focusedClip: ClipSuggestion? {
        guard !displayedClips.isEmpty, focusedClipIndex >= 0, focusedClipIndex < displayedClips.count else { return nil }
        return displayedClips[focusedClipIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            // Clip list
            if displayedClips.isEmpty {
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
        guard !displayedClips.isEmpty else { return }
        let newIndex = focusedClipIndex + direction
        focusedClipIndex = max(0, min(newIndex, displayedClips.count - 1))
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
        VStack(spacing: 12) {
            // Top row: Title and selection badge
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

                // Selection count badge
                if !selectedClipIDs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(selectedClipIDs.count) of \(displayedClips.count) selected")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }

                Button {
                    if selectedClipIDs.count == displayedClips.count && !displayedClips.isEmpty {
                        selectedClipIDs.removeAll()
                    } else {
                        selectedClipIDs = Set(displayedClips.map(\.id))
                    }
                } label: {
                    if selectedClipIDs.count == displayedClips.count && !displayedClips.isEmpty {
                        Text("Deselect All")
                    } else {
                        Text("Select All")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Bottom row: Sort and filter controls
            HStack(spacing: 16) {
                // Sort toggle
                HStack(spacing: 6) {
                    Text("Sort:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Sort", selection: $sortOrder) {
                        ForEach(ClipSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 140)
                }

                Divider()
                    .frame(height: 20)

                // Virality filter
                HStack(spacing: 6) {
                    Text("Show:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Filter", selection: $viralityFilter) {
                        ForEach(ViralityFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }

                Spacer()

                // Filtered count if different from total
                if displayedClips.count != clips.count {
                    Text("Showing \(displayedClips.count) of \(clips.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: viralityFilter) { _, _ in
            // Reset focus when filter changes to avoid out-of-bounds
            focusedClipIndex = 0
        }
        .onChange(of: sortOrder) { _, _ in
            // Reset focus when sort changes
            focusedClipIndex = 0
        }
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(displayedClips.enumerated()), id: \.element.id) { index, clip in
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
                if newIndex >= 0 && newIndex < displayedClips.count {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(displayedClips[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: viralityFilter != .all ? "line.3.horizontal.decrease.circle" : "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if viralityFilter != .all && !clips.isEmpty {
                Text("No clips match filter")
                    .font(.headline)

                Text("No clips have a virality score of \(viralityFilter.minScore) or higher. Try lowering the filter threshold.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Show All Clips") {
                    viralityFilter = .all
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("No clips found")
                    .font(.headline)

                Text("The AI couldn't identify any viral-worthy moments in this video.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        VStack(spacing: 8) {
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
                .help("Export selected clips (Command + Return)")
                .accessibilityHint("Opens export settings for \(selectedClipIDs.count) selected clips")
            }

            // Keyboard shortcuts hint
            HStack(spacing: 16) {
                keyboardHint(key: "Up/Down", action: "Navigate")
                keyboardHint(key: "Space", action: "Select")
                keyboardHint(key: "Cmd+Return", action: "Export")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private func keyboardHint(key: String, action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(action)
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
