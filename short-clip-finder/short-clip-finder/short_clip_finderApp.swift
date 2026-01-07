//
//  short_clip_finderApp.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

@main
struct short_clip_finderApp: App {
    @State private var appState = AppState()
    @State private var showOnboarding = !OnboardingState.hasCompletedOnboarding

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
