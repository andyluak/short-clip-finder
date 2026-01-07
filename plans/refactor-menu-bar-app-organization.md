# ClipFinder: Complete UI Overhaul & App Presentation

**Type:** ✨ Enhancement / ♻️ Refactor
**Created:** 2025-01-08
**Detail Level:** A LOT (Comprehensive)

---

## Overview

Transform ClipFinder from a cramped menu-bar-only utility into a polished, Dock-visible macOS app with distinctive design. The current implementation tries to cram everything into a 320px popover - this overhaul embraces the main window as the primary workspace while keeping a minimal menu bar presence for status.

### Design Philosophy

**Aesthetic Direction: "Editorial Precision"**

Think: Linear app meets Raycast meets Arc browser. Clean, confident, intentional. Not generic startup gradients - but sharp typography, purposeful negative space, and moments of delightful motion.

**Core Principles:**
- **Confident simplicity** - Each screen does one thing exceptionally well
- **Type-first hierarchy** - Let typography carry the design, not gradients
- **Purposeful motion** - Animations that inform, not distract
- **Dark-mode native** - Design for dark first, light as adaptation

---

## Current Problems

| Problem | Severity | Evidence |
|---------|----------|----------|
| **No Dock presence** - Users can't Cmd+Tab to app | High | `LSUIElement = YES` in project |
| **Cramped popover** (475 lines, 320px) | High | `MenuBarPopover.swift` |
| **Generic gradient aesthetic** | Medium | Coral/teal gradients everywhere |
| **Duplicate colors** across 4+ files | Medium | EmptyStateView, ClipCardView, Theme |
| **No API key validation** before processing | High | Users waste 3+ min before failure |
| **Dead code** | Low | `MenuBarView.swift` unused |

---

## Proposed Solution

### Architecture Change

```
BEFORE (Menu bar only):
┌─────────────────┐     ┌────────────────────────────┐
│  Menu Bar Icon  │────▶│  Fat Popover (320px)       │
│  (only access)  │     │  - All functionality here  │
└─────────────────┘     └────────────────────────────┘

AFTER (Dock + Menu bar):
┌─────────────────┐     ┌────────────────────────────┐
│    Dock Icon    │────▶│  Main Window (Full App)    │
│  (Primary)      │     │  - URL input               │
└─────────────────┘     │  - Processing              │
         +              │  - Results + Export        │
┌─────────────────┐     └────────────────────────────┘
│  Menu Bar Icon  │────▶ Minimal status popover
│  (Status only)  │      (processing %, quick open)
└─────────────────┘
```

### Visual Design System

#### Typography

**Display Font:** SF Pro Display (system) with custom weights
- Headlines: 600 weight, tight letter-spacing (-0.02em)
- Body: 400 weight, relaxed line-height (1.5)

**Monospace:** SF Mono for timestamps, percentages, technical info

#### Color Palette

```swift
// NEW: Refined palette - less is more
extension Color {
    // Primary actions - warm amber instead of coral
    static let cfAccent = Color(hex: "F59E0B")     // Amber-500
    static let cfAccentHover = Color(hex: "D97706") // Amber-600

    // Success states
    static let cfSuccess = Color(hex: "10B981")    // Emerald-500

    // Backgrounds (dark mode first)
    static let cfSurface = Color(hex: "18181B")    // Zinc-900
    static let cfSurfaceElevated = Color(hex: "27272A") // Zinc-800
    static let cfSurfaceHover = Color(hex: "3F3F46")    // Zinc-700

    // Text
    static let cfTextPrimary = Color(hex: "FAFAFA")   // Zinc-50
    static let cfTextSecondary = Color(hex: "A1A1AA") // Zinc-400
    static let cfTextMuted = Color(hex: "71717A")     // Zinc-500

    // Borders
    static let cfBorder = Color(hex: "3F3F46")        // Zinc-700
    static let cfBorderSubtle = Color(hex: "27272A")  // Zinc-800
}
```

#### Spacing Scale

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

---

## Technical Approach

### Phase 0: Enable Dock Icon

**Change:** Remove `LSUIElement = YES` from project settings

```swift
// In Xcode project settings or Info.plist:
// REMOVE: INFOPLIST_KEY_LSUIElement = YES
// This makes the app appear in Dock
```

**File:** `short-clip-finder.xcodeproj/project.pbxproj`
- Remove lines 273 and 305: `INFOPLIST_KEY_LSUIElement = YES;`

**Result:** App appears in Dock, supports Cmd+Tab, standard macOS window behavior

---

### Phase 1: Simplified Menu Bar Popover

**Goal:** Menu bar becomes status-only (not the primary interface)

```swift
// MenuBarPopover.swift - Complete rewrite (~120 lines)
struct MenuBarPopover: View {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header: App name + open button
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 14)

            // Processing status (only when active)
            if appState.currentScreen == .processing {
                ProcessingStatusRow(appState: appState)
                    .padding(14)
                Divider()
                    .padding(.horizontal, 14)
            }

            // Quick recent (most recent only)
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

            // Quit
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
        .frame(width: 240) // Narrower than before
        .background(.ultraThinMaterial)
    }

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Compact processing status
struct ProcessingStatusRow: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(Color.cfAccent.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.cfAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
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

    private var progress: Double { /* ... */ }
    private var phaseName: String { /* ... */ }
}
```

---

### Phase 2: Redesigned Main Window

#### 2a. Empty State - Bold Welcome

```swift
struct EmptyStateView: View {
    let appState: AppState
    @State private var urlText = ""
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Main action area
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Bold headline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Find viral clips")
                            .font(.system(size: 42, weight: .bold, design: .default))
                            .tracking(-0.5)

                        Text("Drop a video or paste a URL to discover \nshare-worthy moments.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }

                    Spacer().frame(height: 48)

                    // URL Input - clean, minimal
                    HStack(spacing: 12) {
                        TextField("Paste YouTube, Vimeo, or video URL...", text: $urlText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.cfSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.cfBorder, lineWidth: 1)
                            )

                        Button(action: processURL) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 48)
                                .background(Color.cfAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(urlText.isEmpty)
                        .opacity(urlText.isEmpty ? 0.5 : 1)
                    }
                    .frame(maxWidth: 500)

                    Spacer().frame(height: 24)

                    // Keyboard hints
                    HStack(spacing: 20) {
                        KeyboardHint(key: "⌘N", label: "New URL")
                        KeyboardHint(key: "⌘O", label: "Open File")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                    Spacer()
                }
                .padding(.leading, 64)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: Drop zone + Recent projects
                VStack(spacing: 24) {
                    // Drop zone
                    DropZoneView(isTargeted: $isDropTargeted) { url in
                        appState.processVideo(url: url)
                    }
                    .frame(width: 280, height: 200)

                    // Recent projects (if any)
                    if !appState.recentProjects.isEmpty {
                        RecentProjectsGrid(
                            projects: Array(appState.recentProjects.prefix(4)),
                            onSelect: { project in
                                Task { await appState.loadProject(project.id) }
                            }
                        )
                        .frame(width: 280)
                    }
                }
                .padding(.trailing, 64)
                .frame(width: geometry.size.width * 0.4)
            }
        }
        .background(Color.cfSurface)
    }
}

// Clean drop zone
struct DropZoneView: View {
    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.cfAccent : Color.cfBorder,
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTargeted ? Color.cfAccent.opacity(0.1) : Color.clear)
                )

            VStack(spacing: 12) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "film.stack")
                    .font(.system(size: 32))
                    .foregroundStyle(isTargeted ? Color.cfAccent : .secondary)

                Text(isTargeted ? "Release to analyze" : "Drop video file")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isTargeted ? Color.cfAccent : .secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            // Handle drop...
            true
        }
    }
}

// Recent projects as compact grid
struct RecentProjectsGrid: View {
    let projects: [ProjectSummary]
    let onSelect: (ProjectSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(1)

            VStack(spacing: 8) {
                ForEach(projects) { project in
                    RecentProjectRow(project: project, onSelect: { onSelect(project) })
                }
            }
        }
    }
}

struct RecentProjectRow: View {
    let project: ProjectSummary
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Thumbnail or placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cfSurfaceElevated)
                    .frame(width: 48, height: 32)
                    .overlay {
                        if let path = project.thumbnailPath,
                           let image = NSImage(contentsOfFile: path) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text("\(project.clipCount) clips")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.cfSurfaceHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
```

#### 2b. Processing View - Elegant Progress

```swift
struct ProcessingView: View {
    let appState: AppState
    let videoTitle: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Central focus: Current phase
            VStack(spacing: 32) {
                // Phase icon with subtle animation
                PhaseIcon(phase: appState.currentPhase)
                    .frame(width: 80, height: 80)

                // Phase title
                Text(phaseTitle)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.3)

                // Video title (subtle)
                Text(videoTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Progress bar - clean, horizontal
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cfSurfaceElevated)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cfAccent)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(width: 300, height: 4)

                    HStack {
                        Text(phaseStatus)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 300)
                }
            }

            Spacer()

            // Phase steps at bottom
            HStack(spacing: 32) {
                PhaseStep(
                    number: 1,
                    label: "Download",
                    isComplete: phaseIndex > 0,
                    isActive: phaseIndex == 0
                )

                PhaseConnector(isActive: phaseIndex >= 1)

                PhaseStep(
                    number: 2,
                    label: "Transcribe",
                    isComplete: phaseIndex > 1,
                    isActive: phaseIndex == 1
                )

                PhaseConnector(isActive: phaseIndex >= 2)

                PhaseStep(
                    number: 3,
                    label: "Analyze",
                    isComplete: phaseIndex > 2,
                    isActive: phaseIndex == 2
                )
            }
            .padding(.bottom, 48)

            // Cancel button
            Button("Cancel Processing") {
                appState.cancelProcessing()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cfSurface)
    }

    private var progress: Double { /* ... */ }
    private var phaseTitle: String { /* ... */ }
    private var phaseStatus: String { /* ... */ }
    private var phaseIndex: Int { /* ... */ }
}

struct PhaseStep: View {
    let number: Int
    let label: String
    let isComplete: Bool
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.cfSuccess : (isActive ? Color.cfAccent : Color.cfSurfaceElevated))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isActive ? .black : .secondary)
                }
            }

            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive || isComplete ? .primary : .secondary)
        }
    }
}
```

#### 2c. Results View - Clean Card Layout

```swift
struct ResultsView: View {
    let appState: AppState
    let videoTitle: String
    let videoURL: URL
    let clips: [ClipSuggestion]
    @Binding var selectedClipIDs: Set<UUID>

    @State private var sortOrder: ClipSortOrder = .virality
    @State private var focusedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ResultsHeader(
                videoTitle: videoTitle,
                clipCount: clips.count,
                selectedCount: selectedClipIDs.count,
                sortOrder: $sortOrder,
                onSelectAll: selectAll,
                onDeselectAll: deselectAll
            )

            Divider()

            // Clip list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(sortedClips.enumerated()), id: \.element.id) { index, clip in
                        ClipCard(
                            clip: clip,
                            videoURL: videoURL,
                            isSelected: selectedClipIDs.contains(clip.id),
                            isFocused: index == focusedIndex,
                            onToggle: { toggleSelection(clip.id) }
                        )
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer with export
            ResultsFooter(
                selectedCount: selectedClipIDs.count,
                totalDuration: selectedDuration,
                onExport: { appState.showExportSettings = true }
            )
        }
        .background(Color.cfSurface)
    }
}

// Redesigned clip card - horizontal layout, cleaner
struct ClipCard: View {
    let clip: ClipSuggestion
    let videoURL: URL
    let isSelected: Bool
    let isFocused: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            Rectangle()
                .fill(isSelected ? Color.cfAccent : Color.clear)
                .frame(width: 3)

            // Video preview
            VideoPreviewPlayer(videoURL: videoURL, startTime: clip.startTime, endTime: clip.endTime)
                .frame(width: 180, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    Text(clip.formattedDuration)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Virality score + hook
                HStack(alignment: .top, spacing: 12) {
                    ViralityScore(score: clip.viralityScore)

                    Text("\"\(clip.hookQuote)\"")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                }

                // Timestamp
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(clip.formattedTimeRange)
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(.secondary)

                // Reasoning
                Text(clip.reasoning)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Selection button
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.cfAccent : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(cardBorder, lineWidth: isFocused ? 2 : 0)
        )
        .onHover { isHovered = $0 }
    }

    private var cardBackground: Color {
        if isFocused { return Color.cfAccent.opacity(0.08) }
        if isHovered { return Color.cfSurfaceHover }
        if isSelected { return Color.cfAccent.opacity(0.04) }
        return Color.cfSurfaceElevated
    }

    private var cardBorder: Color {
        isFocused ? Color.cfAccent : Color.clear
    }
}

// Clean virality score badge
struct ViralityScore: View {
    let score: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
            Text("\(score)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(scoreColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(scoreColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var scoreColor: Color {
        if score >= 90 { return Color(hex: "EF4444") }      // Red
        if score >= 80 { return Color(hex: "F59E0B") }      // Amber
        if score >= 70 { return Color(hex: "10B981") }      // Green
        return Color(hex: "6B7280")                          // Gray
    }
}
```

---

### Phase 3: Theme System Consolidation

```swift
// Theme.swift - Complete rewrite

import SwiftUI

enum Theme {
    // MARK: - Colors
    enum Colors {
        // Accent
        static let accent = Color(hex: "F59E0B")
        static let accentHover = Color(hex: "D97706")

        // Semantic
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")

        // Surfaces
        static let surface = Color(hex: "18181B")
        static let surfaceElevated = Color(hex: "27272A")
        static let surfaceHover = Color(hex: "3F3F46")

        // Text
        static let textPrimary = Color(hex: "FAFAFA")
        static let textSecondary = Color(hex: "A1A1AA")
        static let textMuted = Color(hex: "71717A")

        // Borders
        static let border = Color(hex: "3F3F46")
        static let borderSubtle = Color(hex: "27272A")
    }

    // MARK: - Typography
    enum Typography {
        static let displayLarge = Font.system(size: 42, weight: .bold)
        static let displayMedium = Font.system(size: 28, weight: .semibold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 14)
        static let caption = Font.system(size: 12)
        static let small = Font.system(size: 11)
        static let mono = Font.system(size: 12, design: .monospaced)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
    }

    // MARK: - Animation
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
    }
}

// Color hex extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
```

---

### Phase 4: App Entry Point Updates

```swift
// short_clip_finderApp.swift

@main
struct ClipFinderApp: App {
    @State private var appState = AppState()
    @State private var showOnboarding = !OnboardingState.hasCompletedOnboarding

    var body: some Scene {
        // Menu bar (status only)
        MenuBarExtra {
            MenuBarPopover(appState: appState)
        } label: {
            MenuBarIcon(appState: appState)
        }
        .menuBarExtraStyle(.window)

        // Main window (primary interface)
        WindowGroup("ClipFinder", id: "main") {
            MainWindow(appState: appState)
                .sheet(isPresented: $showOnboarding) {
                    WelcomeView(isPresented: $showOnboarding)
                }
                .preferredColorScheme(.dark) // Dark mode first
        }
        .defaultSize(width: 1000, height: 700) // Larger default
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New from URL...") {
                    openMainWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New from File...") {
                    appState.openFilePicker()
                    openMainWindow()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        // Settings
        Settings {
            SettingsWindow()
        }
    }

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

---

## Implementation Phases

### Phase 0: Dock Icon
- [ ] Remove `INFOPLIST_KEY_LSUIElement = YES` from project.pbxproj (lines 273, 305)
- [ ] Test app appears in Dock
- [ ] Verify Cmd+Tab works

### Phase 1: Theme System
- [ ] Create new `Theme.swift` with Colors, Typography, Spacing
- [ ] Remove color definitions from EmptyStateView.swift
- [ ] Remove color definitions from ClipCardView.swift
- [ ] Delete unused MenuBarView.swift

### Phase 2: Menu Bar Popover
- [ ] Rewrite MenuBarPopover.swift (~120 lines)
- [ ] Update frame width to 240px
- [ ] Test processing status display
- [ ] Test recent project loading

### Phase 3: Empty State
- [ ] Redesign EmptyStateView with split layout
- [ ] Implement clean drop zone
- [ ] Implement recent projects grid
- [ ] Update URL input styling

### Phase 4: Processing View
- [ ] Redesign ProcessingView with central focus
- [ ] Implement phase steps indicator
- [ ] Add clean progress bar

### Phase 5: Results View
- [ ] Redesign ResultsView header/footer
- [ ] Rewrite ClipCard with horizontal layout
- [ ] Implement new ViralityScore badge
- [ ] Test selection and keyboard navigation

### Phase 6: Polish
- [ ] Add enter/exit animations
- [ ] Test all keyboard shortcuts
- [ ] Run full type check
- [ ] Build and test complete workflow

---

## Acceptance Criteria

### Functional
- [ ] App appears in Dock
- [ ] Menu bar shows minimal popover with status
- [ ] Main window is primary workspace
- [ ] All existing functionality preserved
- [ ] Keyboard shortcuts work (⌘N, ⌘O, ⌘Q, arrows, space)

### Visual
- [ ] Dark mode native design
- [ ] Amber accent color throughout
- [ ] Clean typography hierarchy
- [ ] No coral/teal gradient vestiges
- [ ] Consistent spacing scale

### Quality
- [ ] Type check passes
- [ ] Build succeeds
- [ ] No console errors
- [ ] Smooth animations

---

## Files Changed

| File | Action | Notes |
|------|--------|-------|
| `project.pbxproj` | Edit | Remove LSUIElement |
| `Theme.swift` | Rewrite | New color/type system |
| `MenuBarPopover.swift` | Rewrite | Simplified to ~120 lines |
| `MenuBarView.swift` | Delete | Unused |
| `EmptyStateView.swift` | Rewrite | New split layout |
| `ProcessingView.swift` | Rewrite | Central focus design |
| `ResultsView.swift` | Rewrite | Clean card layout |
| `ClipCardView.swift` | Rewrite | Horizontal layout |
| `short_clip_finderApp.swift` | Edit | Larger default window |

---

## Checklist Summary

- [ ] **Phase 0:** Dock icon enabled
- [ ] **Phase 1:** Theme system consolidated
- [ ] **Phase 2:** Menu bar simplified
- [ ] **Phase 3:** Empty state redesigned
- [ ] **Phase 4:** Processing view redesigned
- [ ] **Phase 5:** Results view redesigned
- [ ] **Phase 6:** Polish and testing
- [ ] **Final:** Full build passes, app works end-to-end
