//
//  MainWindow.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct MainWindow: View {
    let appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .empty:
                EmptyStateView(appState: appState)
            case .processing:
                ProcessingView(appState: appState, videoTitle: appState.videoTitle)
            case .results:
                if let videoURL = appState.videoURL {
                    ResultsView(
                        appState: appState,
                        videoTitle: appState.videoTitle,
                        videoURL: videoURL,
                        clips: appState.clipSuggestions,
                        selectedClipIDs: Binding(
                            get: { appState.selectedClipIDs },
                            set: { appState.selectedClipIDs = $0 }
                        )
                    )
                } else {
                    TranscriptDebugView(appState: appState)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(.background)
    }
}
