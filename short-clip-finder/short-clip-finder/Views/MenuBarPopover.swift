//
//  MenuBarPopover.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import AppKit

// MARK: - Menu Bar Icon

struct MenuBarIcon: View {
    let appState: AppState

    var body: some View {
        ZStack {
            Image(systemName: "film.stack")

            if appState.currentScreen == .processing {
                Circle()
                    .fill(Color.cfAccent)
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

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .padding(.horizontal, 14)

            if appState.currentScreen == .processing {
                ProcessingStatusRow(appState: appState)
                    .padding(14)
                Divider()
                    .padding(.horizontal, 14)
            }

            if let recent = appState.recentProjects.first {
                RecentRow(project: recent) {
                    Task { await appState.loadProject(recent.id) }
                    openMainWindow()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                Divider()
                    .padding(.horizontal, 14)
            }

            quitButton
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("ClipFinder")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button(action: openMainWindow) {
                Image(systemName: "macwindow")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open main window")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Quit Button

    private var quitButton: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            HStack {
                Text("Quit")
                    .font(.system(size: 12))
                Spacer()
                Text("⌘Q")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Processing Status Row

struct ProcessingStatusRow: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.cfAccent.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(phaseName)
                    .font(.system(size: 11, weight: .medium))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                appState.cancelProcessing()
            }
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.8))
        }
    }

    private var progress: Double {
        switch appState.currentPhase {
        case .downloading(let progress, _): return progress
        case .transcribing(let progress, _): return progress
        case .analyzing(let progress, _): return progress
        case .complete: return 1.0
        case .failed: return 0
        }
    }

    private var phaseName: String {
        switch appState.currentPhase {
        case .downloading: return "Downloading"
        case .transcribing: return "Transcribing"
        case .analyzing: return "Analyzing"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Recent Row

private struct RecentRow: View {
    let project: ProjectSummary
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    if let thumbnailPath = project.thumbnailPath,
                       let image = NSImage(contentsOfFile: thumbnailPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.cfSurfaceElevated
                        Image(systemName: "film")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text("\(project.clipCount) clips")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.vertical, 4)
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

// MARK: - Visual Effect Blur (legacy support)

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
        .frame(width: 240)
}
