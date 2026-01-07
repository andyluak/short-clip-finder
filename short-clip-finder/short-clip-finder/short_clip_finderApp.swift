//
//  short_clip_finderApp.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import Combine

/// Singleton to bridge AppDelegate and SwiftUI window opening
final class WindowOpener: ObservableObject {
    static let shared = WindowOpener()
    @Published var shouldOpenWindow = false

    private init() {}

    func requestOpenWindow() {
        shouldOpenWindow = true
    }
}

@main
struct short_clip_finderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var showOnboarding = !OnboardingState.hasCompletedOnboarding
    @StateObject private var windowOpener = WindowOpener.shared
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
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New from URL...") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New from File...") {
                    openWindow(id: "main")
                    appState.shouldShowFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        .onChange(of: windowOpener.shouldOpenWindow) { _, shouldOpen in
            if shouldOpen {
                windowOpener.shouldOpenWindow = false
                openWindow(id: "main")
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
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Called when Dock icon is clicked
        WindowOpener.shared.requestOpenWindow()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Only trigger if there are no visible normal windows
        let hasAnyVisibleWindow = NSApp.windows.contains { window in
            window.isVisible && window.level == .normal && window.canBecomeKey
        }
        if !hasAnyVisibleWindow {
            WindowOpener.shared.requestOpenWindow()
        }
    }
}
