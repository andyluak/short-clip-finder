//
//  ClipCardView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ClipCardView: View {
    let clip: ClipSuggestion
    let videoURL: URL
    @Binding var isSelected: Bool
    var isFocused: Bool = false
    var onTrimUpdate: ((TimeInterval, TimeInterval) -> Void)?

    @State private var isHovered = false
    @State private var showTrimPopover = false

    var body: some View {
        HStack(spacing: 16) {
            // Video Preview
            VideoPreviewPlayer(
                videoURL: videoURL,
                startTime: clip.startTime,
                endTime: clip.endTime
            )
            .frame(width: 160, height: 90)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Top row: Badge + Hook
                HStack(alignment: .top, spacing: 12) {
                    ViralityBadge(score: clip.viralityScore, level: clip.viralityLevel)

                    Text("\"\(clip.hookQuote)\"")
                        .font(.system(.body, weight: .medium))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }

                // Time info
                HStack(spacing: 16) {
                    Label(clip.formattedTimeRange, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(clip.formattedDuration)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Reasoning
                Text(clip.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                Toggle(isOn: $isSelected) {
                    Text("Export")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)

                // Trim button
                Button {
                    showTrimPopover = true
                } label: {
                    Label("Trim", systemImage: "scissors")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showTrimPopover, arrowEdge: .trailing) {
                    TrimPopover(
                        clip: clip,
                        videoURL: videoURL,
                        onSave: { newStart, newEnd in
                            onTrimUpdate?(newStart, newEnd)
                            showTrimPopover = false
                        },
                        onCancel: {
                            showTrimPopover = false
                        }
                    )
                }
            }
            .frame(width: 70)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isFocused ? Color.accentColor.opacity(0.08) : (isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04)))
                .strokeBorder(
                    isFocused ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.5) : Color.clear),
                    lineWidth: isFocused ? 2 : (isSelected ? 2 : 0)
                )
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clip: \(clip.hookQuote)")
        .accessibilityValue("Virality \(clip.viralityScore), \(clip.formattedDuration)")
        .accessibilityHint(isSelected ? "Selected for export. Press Space to deselect." : "Press Space to select for export.")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }
}

#Preview {
    let mockClip = ClipSuggestion(
        viralityScore: 92,
        hookQuote: "Happiness is a choice you make every single day",
        startTime: 872,
        endTime: 917,
        reasoning: "Strong emotional hook with quotable statement. Perfect for motivation content."
    )

    ClipCardView(
        clip: mockClip,
        videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
        isSelected: .constant(true)
    )
    .frame(width: 600)
    .padding()
}
