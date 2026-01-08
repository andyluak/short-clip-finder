//
//  TranscriptDrawer.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 08.01.2026.
//

import SwiftUI

struct TranscriptDrawer: View {
    let segments: [TranscriptSegment]
    let currentClipTimeRange: ClosedRange<TimeInterval>?
    let onClose: () -> Void
    let onTimestampTapped: ((TimeInterval) -> Void)?
    var onSegmentEdited: ((UUID, String) -> Void)?

    @State private var drawerWidth: CGFloat = 320
    @State private var isEditing = false
    @State private var editedTexts: [UUID: String] = [:]

    private let minWidth: CGFloat = 280
    private let maxWidth: CGFloat = 450

    var body: some View {
        HStack(spacing: 0) {
            // Resize handle
            resizeHandle

            // Drawer content
            VStack(spacing: 0) {
                header
                Divider()
                transcriptList
            }
            .frame(width: drawerWidth)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newWidth = drawerWidth - value.translation.width
                        drawerWidth = max(minWidth, min(newWidth, maxWidth))
                    }
            )
    }

    private var header: some View {
        HStack {
            Text("Transcript")
                .font(.headline)

            Spacer()

            // Edit toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing.toggle()
                }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                    .foregroundStyle(isEditing ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isEditing ? "Done editing" : "Edit transcript")

            Button {
                copyAllToClipboard()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy all transcript text")

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(segments) { segment in
                        TranscriptSegmentRow(
                            segment: segment,
                            isHighlighted: isSegmentInCurrentClip(segment),
                            isEditing: isEditing,
                            editedText: Binding(
                                get: { editedTexts[segment.id] ?? segment.text },
                                set: { newValue in
                                    editedTexts[segment.id] = newValue
                                    onSegmentEdited?(segment.id, newValue)
                                }
                            ),
                            onTap: {
                                onTimestampTapped?(segment.start)
                            }
                        )
                        .id(segment.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: currentClipTimeRange) { _, newRange in
                if let range = newRange {
                    scrollToTime(range.lowerBound, proxy: proxy)
                }
            }
        }
    }

    private func isSegmentInCurrentClip(_ segment: TranscriptSegment) -> Bool {
        guard let range = currentClipTimeRange else { return false }
        // Segment overlaps with clip if segment.start is within range or segment spans the range
        return segment.start >= range.lowerBound && segment.start <= range.upperBound
    }

    private func scrollToTime(_ time: TimeInterval, proxy: ScrollViewProxy) {
        // Find the segment closest to this time
        if let segment = segments.first(where: { $0.start >= time }) ?? segments.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(segment.id, anchor: .center)
            }
        }
    }

    private func copyAllToClipboard() {
        let fullText = segments
            .map { "[\(formatTime($0.start))] \($0.text)" }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullText, forType: .string)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}

// MARK: - Segment Row

private struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment
    let isHighlighted: Bool
    let isEditing: Bool
    @Binding var editedText: String
    let onTap: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Timestamp button
            Button {
                onTap()
            } label: {
                Text(formatTime(segment.start))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isHighlighted ? .primary : .secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 55, alignment: .trailing)

            // Segment text - editable or read-only
            if isEditing {
                TextEditor(text: $editedText)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(minHeight: 36)
                    .focused($isFocused)
            } else {
                Text(editedText)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isHighlighted ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}

#Preview {
    let mockSegments = [
        TranscriptSegment(id: UUID(), text: "Welcome to today's video about productivity and focus.", start: 0, end: 5, words: []),
        TranscriptSegment(id: UUID(), text: "The first thing you need to understand is that consistency is key.", start: 5, end: 12, words: []),
        TranscriptSegment(id: UUID(), text: "When I started my journey, I had no idea what I was doing.", start: 12, end: 18, words: []),
        TranscriptSegment(id: UUID(), text: "But over time, things started to click.", start: 18, end: 23, words: [])
    ]

    TranscriptDrawer(
        segments: mockSegments,
        currentClipTimeRange: 5...18,
        onClose: {},
        onTimestampTapped: { _ in },
        onSegmentEdited: { _, _ in }
    )
    .frame(height: 400)
}
