//
//  ExportSettingsPanel.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ExportSettingsPanel: View {
    @Binding var settings: ExportSettings
    @Binding var isPresented: Bool
    let clipCount: Int
    let onExport: () -> Void

    @State private var hoveredFormat: ExportFormat?
    @State private var hoveredQuality: ExportQuality?
    @State private var hoveredCrop: CropMode?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    formatSection
                    qualitySection
                    cropSection
                    outputSection
                }
                .padding(Theme.Spacing.xl)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 440, height: 520)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Gradient.warm)
                    .frame(width: 40, height: 40)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Export Settings")
                    .font(.system(size: 16, weight: .semibold))

                Text("\(clipCount) clip\(clipCount == 1 ? "" : "s") ready to export")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Aspect Ratio", icon: "aspectratio")

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    formatOption(format)
                }
            }
        }
    }

    private func formatOption(_ format: ExportFormat) -> some View {
        let isSelected = settings.format == format
        let isHovered = hoveredFormat == format

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.format = format
            }
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                // Aspect ratio preview
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.cfCoral.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: format.previewWidth, height: format.previewHeight)
                }
                .frame(width: 36, height: 36)

                Text(format.shortName)
                    .font(.system(size: 12, weight: .semibold))

                Text(format.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? Color.cfCoral.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(
                        isSelected ? Color.cfCoral.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredFormat = hovering ? format : nil
        }
    }

    // MARK: - Quality Section

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Quality", icon: "sparkles")

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ExportQuality.allCases, id: \.self) { quality in
                    qualityOption(quality)
                }
            }
        }
    }

    private func qualityOption(_ quality: ExportQuality) -> some View {
        let isSelected = settings.quality == quality
        let isHovered = hoveredQuality == quality

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.quality = quality
            }
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Text(quality.shortName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                Text(quality.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? Color.cfTeal.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(
                        isSelected ? Color.cfTeal.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredQuality = hovering ? quality : nil
        }
    }

    // MARK: - Crop Section

    private var cropSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Crop Focus", icon: "crop")

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(CropMode.allCases, id: \.self) { mode in
                    cropOption(mode)
                }
            }

            // Info text for auto-track
            if settings.cropMode == .autoTrack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.cfTeal)

                    Text("Auto-track will follow detected faces throughout the clip for optimal framing.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Color.cfTeal.opacity(0.08))
                )
            }
        }
    }

    private func cropOption(_ mode: CropMode) -> some View {
        let isSelected = settings.cropMode == mode
        let isHovered = hoveredCrop == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.cropMode = mode
            }
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.cfOrange : .secondary)

                Text(mode.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? Color.cfOrange.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(
                        isSelected ? Color.cfOrange.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredCrop = hovering ? mode : nil
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Save Location", icon: "folder")

            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.cfTeal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.outputDirectory.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text(settings.outputDirectory.deletingLastPathComponent().path)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                Button("Change...") {
                    chooseOutputDirectory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Color.secondary.opacity(0.04))
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Estimated size
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated size")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Text(estimatedSize)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            Spacer()

            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.escape)
            .buttonStyle(.bordered)

            Button {
                settings.save()
                isPresented = false
                onExport()
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export \(clipCount) Clip\(clipCount == 1 ? "" : "s")")
                }
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .tint(Color.cfCoral)
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var estimatedSize: String {
        // Rough estimate based on quality and clip count
        let baseSize: Double
        switch settings.quality {
        case .hd720: baseSize = 10 // MB per 30 sec
        case .hd1080: baseSize = 25
        case .uhd4k: baseSize = 80
        }

        let totalMB = baseSize * Double(clipCount)

        if totalMB < 1000 {
            return String(format: "~%.0f MB", totalMB)
        } else {
            return String(format: "~%.1f GB", totalMB / 1000)
        }
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url
        }
    }
}

// MARK: - ExportFormat Extensions

extension ExportFormat {
    var shortName: String {
        switch self {
        case .vertical: return "9:16"
        case .square: return "1:1"
        case .horizontal: return "16:9"
        }
    }

    var subtitle: String {
        switch self {
        case .vertical: return "TikTok, Reels"
        case .square: return "Instagram"
        case .horizontal: return "YouTube"
        }
    }

    var previewWidth: CGFloat {
        switch self {
        case .vertical: return 18
        case .square: return 28
        case .horizontal: return 32
        }
    }

    var previewHeight: CGFloat {
        switch self {
        case .vertical: return 32
        case .square: return 28
        case .horizontal: return 18
        }
    }
}

// MARK: - ExportQuality Extensions

extension ExportQuality {
    var shortName: String {
        switch self {
        case .hd720: return "720p"
        case .hd1080: return "1080p"
        case .uhd4k: return "4K"
        }
    }

    var subtitle: String {
        switch self {
        case .hd720: return "Smaller files"
        case .hd1080: return "Recommended"
        case .uhd4k: return "If source supports"
        }
    }
}

// MARK: - CropMode Extensions

extension CropMode {
    var icon: String {
        switch self {
        case .autoTrack: return "person.fill.viewfinder"
        case .center: return "viewfinder"
        }
    }
}

#Preview {
    ExportSettingsPanel(
        settings: .constant(.default),
        isPresented: .constant(true),
        clipCount: 5,
        onExport: {}
    )
}
