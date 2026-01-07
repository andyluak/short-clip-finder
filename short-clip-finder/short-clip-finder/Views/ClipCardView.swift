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
    @State private var isAppearing = false

    var body: some View {
        HStack(spacing: 0) {
            // Selection indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.cfAccent : Color.clear)
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 16) {
                // Video Preview with enhanced styling
                ZStack(alignment: .bottomTrailing) {
                    VideoPreviewPlayer(
                        videoURL: videoURL,
                        startTime: clip.startTime,
                        endTime: clip.endTime
                    )
                    .frame(width: 160, height: 90)

                    // Duration overlay
                    Text(clip.formattedDuration)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }

                // Content
                VStack(alignment: .leading, spacing: 10) {
                    // Top row: Badge + Hook
                    HStack(alignment: .top, spacing: 12) {
                        ViralityBadge(score: clip.viralityScore, level: clip.viralityLevel)

                        Text("\"\(clip.hookQuote)\"")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                    }

                    // Time info with enhanced styling
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(clip.formattedTimeRange)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Reasoning with better typography
                    Text(clip.reasoning)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                Spacer()

                // Enhanced Actions
                VStack(spacing: 10) {
                    // Selection toggle button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isSelected.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isSelected ? Color.cfAccent : .secondary)

                            Text(isSelected ? "Selected" : "Select")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? Color.cfAccent : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.cfAccent.opacity(0.12) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Trim button
                    Button {
                        showTrimPopover = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scissors")
                                .font(.system(size: 11))
                            Text("Trim")
                                .font(.system(size: 11, weight: .medium))
                        }
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
                .frame(width: 90)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(
                    color: isFocused ? Color.cfAccent.opacity(0.15) : Color.black.opacity(0.06),
                    radius: isFocused ? 8 : 4,
                    y: 2
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderGradient, lineWidth: isFocused ? 2 : (isSelected ? 1.5 : 0))
        }
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isAppearing = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clip: \(clip.hookQuote)")
        .accessibilityValue("Virality \(clip.viralityScore), \(clip.formattedDuration)")
        .accessibilityHint(isSelected ? "Selected for export. Press Space to deselect." : "Press Space to select for export.")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var cardBackgroundColor: Color {
        if isFocused {
            return Color.cfAccent.opacity(0.06)
        } else if isHovered {
            return Color.cfSurfaceHover
        } else if isSelected {
            return Color.cfAccent.opacity(0.03)
        } else {
            return Color.cfSurfaceElevated
        }
    }

    private var borderGradient: LinearGradient {
        if isFocused {
            return LinearGradient(
                colors: [Color.cfAccent, Color.cfSuccess.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isSelected {
            return LinearGradient(
                colors: [Color.cfAccent.opacity(0.6), Color.cfAccent.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
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
