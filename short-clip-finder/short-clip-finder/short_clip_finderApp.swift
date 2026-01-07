//
//  short_clip_finderApp.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

@main
struct short_clip_finderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var showOnboarding = !OnboardingState.hasCompletedOnboarding
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(appState: appState)
        } label: {
            MenuBarIcon(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Window("ClipFinder", id: "main") {
            MainWindow(appState: appState)
                .sheet(isPresented: $showOnboarding) {
                    WelcomeView(isPresented: $showOnboarding)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                    // AppDelegate requested to open main window
                    openWindow(id: "main")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New from URL...") {
                    appState.openMainWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New from File...") {
                    appState.openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        Window("Settings", id: "settings") {
            SettingsWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Main window opens automatically via SwiftUI
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Called when Dock icon is clicked
        showMainWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Only trigger if there are no visible windows at all
        let hasAnyVisibleWindow = NSApp.windows.contains { window in
            window.isVisible && window.level == .normal
        }
        if !hasAnyVisibleWindow {
            showMainWindow()
        }
    }

    private func showMainWindow() {
        // Post notification for SwiftUI to handle via openWindow
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
