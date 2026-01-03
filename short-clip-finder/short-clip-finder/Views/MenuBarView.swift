//
//  MenuBarView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New from URL...") {
            appState.newProject()
            openOrFocusWindow(id: "main")
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("New from File...") {
            appState.newProject()
            appState.openFilePicker()
            openOrFocusWindow(id: "main")
        }
        .keyboardShortcut("o", modifiers: .command)

        Divider()

        // Processing status (if active)
        if appState.currentScreen == .processing {
            processingStatus
            Divider()
        }

        // Recent projects
        if !appState.recentProjects.isEmpty {
            recentProjectsMenu
            Divider()
        }

        Button("Settings...") {
            openOrFocusWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit ClipFinder") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Processing Status

    private var processingStatus: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text(processingStatusText)
                .foregroundStyle(.secondary)
        }
    }

    private var processingStatusText: String {
        switch appState.currentPhase {
        case .downloading(_, let status):
            return status
        case .transcribing(let progress):
            return "Transcribing... \(Int(progress * 100))%"
        case .analyzing(let progress):
            return "Analyzing... \(Int(progress * 100))%"
        case .complete:
            return "Complete"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    // MARK: - Recent Projects

    private var recentProjectsMenu: some View {
        Menu("Recent Projects") {
            ForEach(appState.recentProjects.prefix(5)) { project in
                Button {
                    Task {
                        await appState.loadProject(project.id)
                        openOrFocusWindow(id: "main")
                    }
                } label: {
                    HStack {
                        Text(project.title)
                        Spacer()
                        Text("\(project.clipCount) clips")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if appState.recentProjects.count > 5 {
                Divider()
                Text("\(appState.recentProjects.count - 5) more...")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Clear Recent Projects") {
                Task {
                    try? await ProjectManager.shared.deleteAllProjects()
                    await appState.loadRecentProjects()
                }
            }
        }
    }

    // MARK: - Window Management

    private func openOrFocusWindow(id: String) {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == id }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openWindow(id: id)
            // Activate after a short delay to ensure window is created
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
