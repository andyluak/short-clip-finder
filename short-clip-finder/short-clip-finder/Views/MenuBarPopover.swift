//
//  MenuBarPopover.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import AppKit

// MARK: - Menu Bar Icon (with processing indicator)

struct MenuBarIcon: View {
    let appState: AppState

    var body: some View {
        ZStack {
            Image(systemName: "film.stack")

            // Show indicator dot when processing
            if appState.currentScreen == .processing {
                Circle()
                    .fill(Color.cfCoral)
                    .frame(width: 6, height: 6)
                    .offset(x: 6, y: -5)
            }
        }
    }
}

// MARK: - Menu Bar Popover

struct MenuBarPopover: View {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var hoveredAction: QuickAction?

    enum QuickAction: String, CaseIterable {
        case newURL = "New from URL"
        case newFile = "New from File"
        case settings = "Settings"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with branding
            header

            Divider()
                .padding(.horizontal, Theme.Spacing.md)

            // Processing status (if active)
            if appState.currentScreen == .processing {
                processingCard
                    .padding(Theme.Spacing.md)

                Divider()
                    .padding(.horizontal, Theme.Spacing.md)
            }

            // Quick actions
            quickActions
                .padding(Theme.Spacing.md)

            // Recent projects
            if !appState.recentProjects.isEmpty {
                Divider()
                    .padding(.horizontal, Theme.Spacing.md)

                recentProjects
                    .padding(Theme.Spacing.md)
            }

            Divider()
                .padding(.horizontal, Theme.Spacing.md)

            // Footer
            footer
        }
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // App icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Gradient.primary)
                    .frame(width: 28, height: 28)

                Image(systemName: "film.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("ClipFinder")
                    .font(.system(size: 13, weight: .semibold))

                Text("Find viral moments")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Open main window
            Button {
                openOrFocusWindow(id: "main")
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open main window")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Processing Card

    private var processingCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.cfCoral.opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(
                            Theme.Gradient.warm,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progressValue)

                    Image(systemName: phaseIcon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cfCoral)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseTitle)
                        .font(.system(size: 12, weight: .medium))

                    Text(phaseSubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(Int(progressValue * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.cfCoral)
                    .monospacedDigit()
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.cfCoral.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .strokeBorder(Color.cfCoral.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var progressValue: Double {
        switch appState.currentPhase {
        case .downloading(let progress, _): return progress
        case .transcribing(let progress, _): return progress
        case .analyzing(let progress, _): return progress
        case .complete: return 1.0
        case .failed: return 0
        }
    }

    private var phaseIcon: String {
        switch appState.currentPhase {
        case .downloading: return "arrow.down.circle"
        case .transcribing: return "waveform"
        case .analyzing: return "sparkles"
        case .complete: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var phaseTitle: String {
        switch appState.currentPhase {
        case .downloading: return "Downloading"
        case .transcribing: return "Transcribing"
        case .analyzing: return "Finding clips"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    private var phaseSubtitle: String {
        switch appState.currentPhase {
        case .downloading(_, let status): return status
        case .transcribing(_, let status): return status.isEmpty ? "Converting speech to text..." : status
        case .analyzing(_, let status): return status.isEmpty ? "AI analyzing transcript..." : status
        case .complete: return "Ready to export"
        case .failed(let message): return message
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: Theme.Spacing.xs) {
            quickActionButton(
                action: .newURL,
                icon: "link",
                shortcut: "N"
            ) {
                appState.newProject()
                openOrFocusWindow(id: "main")
            }

            quickActionButton(
                action: .newFile,
                icon: "doc.badge.plus",
                shortcut: "O"
            ) {
                appState.newProject()
                appState.openFilePicker()
                openOrFocusWindow(id: "main")
            }

            quickActionButton(
                action: .settings,
                icon: "gearshape",
                shortcut: ","
            ) {
                openOrFocusWindow(id: "settings")
            }
        }
    }

    private func quickActionButton(
        action: QuickAction,
        icon: String,
        shortcut: String,
        handler: @escaping () -> Void
    ) -> some View {
        Button(action: handler) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(hoveredAction == action ? Color.cfCoral : .secondary)
                    .frame(width: 20)

                Text(action.rawValue)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Text("⌘\(shortcut)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(hoveredAction == action ? Color.cfCoral.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredAction = isHovered ? action : nil
            }
        }
    }

    // MARK: - Recent Projects

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Recent")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if appState.recentProjects.count > 3 {
                    Text("\(appState.recentProjects.count) total")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            ForEach(appState.recentProjects.prefix(3)) { project in
                RecentProjectRow(project: project) {
                    Task {
                        await appState.loadProject(project.id)
                        openOrFocusWindow(id: "main")
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("v1.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))

                    Text("⌘Q")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Window Management

    private func openOrFocusWindow(id: String) {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == id }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openWindow(id: id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// MARK: - Recent Project Row

private struct RecentProjectRow: View {
    let project: ProjectSummary
    let action: () -> Void

    @State private var isHovered = false

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: project.updatedAt, relativeTo: Date())
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                // Thumbnail or placeholder
                ZStack {
                    if let thumbnailPath = project.thumbnailPath,
                       let image = NSImage(contentsOfFile: thumbnailPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [Color.cfTeal.opacity(0.4), Color.cfCoral.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: "film")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 32, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 4) {
                        Text("\(project.clipCount) clips")
                        Text("·")
                        Text(formattedDate)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview("Menu Bar Popover") {
    MenuBarPopover(appState: AppState())
        .frame(width: 320)
}
