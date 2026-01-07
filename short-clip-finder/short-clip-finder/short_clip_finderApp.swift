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
                .background(WindowAccessor())
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

// MARK: - Window Accessor

/// Captures a reference to the main window for AppDelegate to use
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                AppDelegate.mainWindow = window
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window, AppDelegate.mainWindow == nil {
            AppDelegate.mainWindow = window
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var mainWindow: NSWindow?

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
        // Check if our stored main window exists and is visible
        if let mainWindow = AppDelegate.mainWindow, mainWindow.isVisible {
            return
        }

        // No main window visible, show it
        showMainWindow()
    }

    private func showMainWindow() {
        // Use stored reference to main window
        if let window = AppDelegate.mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Window doesn't exist yet - find by title as fallback
        if let window = NSApp.windows.first(where: { $0.title == "ClipFinder" }) {
            AppDelegate.mainWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Last resort: find any sizeable window that's not a menu bar panel
        if let window = NSApp.windows.first(where: {
            $0.contentView != nil &&
            $0.frame.width > 400 &&
            $0.level == .normal
        }) {
            AppDelegate.mainWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Just activate - SwiftUI should show the window
        NSApp.activate(ignoringOtherApps: true)
    }
}
