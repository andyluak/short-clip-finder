# ClipFinder - Implementation Plan

**Date:** 2026-01-03
**Design Doc:** [2026-01-03-clipfinder-design.md](./2026-01-03-clipfinder-design.md)

---

## Phase Overview

| Phase | Focus | Deliverable | Test Checkpoint | Status |
|-------|-------|-------------|-----------------|--------|
| **1** | Foundation | Menu bar app shell + window | App launches, shows in menu bar | **DONE** |
| **2** | Local Pipeline | Transcribe local files | Drop MP4 → see transcript | **DONE** |
| **3** | AI Analysis | GPT clip suggestions | Transcript → viral clips list | **DONE** |
| **4** | YouTube Download | yt-dlp integration | Paste URL → download works | **DONE** |
| **5** | Face Detection | Vision framework tracking | Video → face positions JSON | **DONE** |
| **6** | Export Engine | FFmpeg 9:16 crop | Clips export with speaker tracking | **DONE** |
| **7** | Polish | Settings, errors, persistence | Production-ready MVP | **DONE** |

---

## Phase 1: Foundation (Menu Bar Shell)

**Goal:** App launches in menu bar, opens main window, basic navigation works.

### Tasks

```
1.1 Convert to menu bar app
    - Add MenuBarExtra to App.swift
    - Remove Dock icon (Info.plist: LSUIElement = YES)
    - Add app icon to menu bar

1.2 Create main window
    - WindowGroup with .windowStyle(.hiddenTitleBar) or similar
    - Basic 800x600 window
    - Close button hides (not quits)

1.3 Menu bar dropdown
    - "New from URL..." (⌘N) → opens main window
    - "New from File..." (⌘O) → opens file picker
    - Separator
    - "Settings..." (⌘,)
    - "Quit ClipFinder" (⌘Q)

1.4 Basic state management
    - AppState @Observable class
    - enum AppScreen { empty, processing, results }
```

### Test Checkpoint

```
✓ App appears in menu bar (not Dock)
✓ Clicking icon shows dropdown menu
✓ ⌘N opens main window
✓ ⌘Q quits the app
✓ Window can be closed and reopened
```

### Files to Create

```
Sources/
├── ClipFinderApp.swift          (MenuBarExtra setup)
├── Models/
│   └── AppState.swift           (@Observable state)
├── Views/
│   ├── MenuBarView.swift        (dropdown content)
│   ├── MainWindow.swift         (window container)
│   └── EmptyStateView.swift     (URL input UI)
```

---

## Phase 2: Local Transcription Pipeline

**Goal:** Drop a local video file → WhisperKit transcribes → show transcript with timestamps.

### Tasks

```
2.1 WhisperKit integration
    - Add WhisperKit via SPM
    - Model download manager (first-launch flow)
    - Store models in ~/Library/Application Support/ClipFinder/models/

2.2 File drop zone
    - Drag-and-drop MP4/MOV onto EmptyStateView
    - File picker via ⌘O
    - Validate supported formats

2.3 Transcription service
    - TranscriptionService actor
    - Progress reporting (0-100%)
    - Output: [TranscriptWord] with start/end timestamps

2.4 Processing UI
    - ProcessingView with progress bar
    - Three phases shown (even if only transcription runs)
    - Cancel button

2.5 Transcript display (temporary, for testing)
    - Raw transcript text view
    - Word timestamps visible
```

### Test Checkpoint

```
✓ First launch prompts for model download
✓ Model downloads with progress indicator
✓ Drag MP4 onto window → processing starts
✓ Progress bar updates during transcription
✓ Cancel button stops transcription
✓ Transcript appears with timestamps
✓ Works offline after model downloaded
```

### Files to Create

```
Sources/
├── Services/
│   ├── TranscriptionService.swift
│   └── ModelManager.swift
├── Models/
│   ├── TranscriptWord.swift
│   └── ProcessingPhase.swift
├── Views/
│   ├── FileDropZone.swift
│   ├── ProcessingView.swift
│   ├── ModelDownloadView.swift
│   └── TranscriptDebugView.swift   (temporary)
```

---

## Phase 3: AI Clip Analysis

**Goal:** Send transcript to GPT → receive viral clip suggestions → display in UI.

### Tasks

```
3.1 API key management
    - Settings window with API key input
    - Store in Keychain (not UserDefaults)
    - Validate key on entry

3.2 GPT service
    - AnalysisService actor
    - Prompt engineering for viral clip detection
    - Parse response into [ClipSuggestion]

3.3 Clip suggestion model
    - ClipSuggestion struct
    - viralityScore: Int (0-100)
    - hookQuote: String
    - startTime/endTime: TimeInterval
    - reasoning: String

3.4 Results UI
    - ClipCardView component
    - Virality badge (color-coded)
    - Hook quote display
    - Timestamp range
    - Checkbox for selection

3.5 Basic clip preview
    - AVPlayer inline preview
    - Play/pause on click
    - Seek to clip start time
```

### Test Checkpoint

```
✓ Settings → API key saves to Keychain
✓ Invalid API key shows error
✓ After transcription → "Analyzing..." phase runs
✓ Clip cards appear with scores and hooks
✓ Cards are selectable (checkbox)
✓ Click thumbnail plays video preview
✓ Scores look reasonable for test content
```

### Files to Create

```
Sources/
├── Services/
│   ├── AnalysisService.swift
│   └── KeychainManager.swift
├── Models/
│   └── ClipSuggestion.swift
├── Views/
│   ├── ResultsView.swift
│   ├── ClipCardView.swift
│   ├── ViralityBadge.swift
│   ├── VideoPreviewPlayer.swift
│   └── SettingsWindow.swift
```

### Prompt Engineering Notes

```
System prompt structure:
- Role: "Video content analyst for short-form viral content"
- Task: Find 5 best clips (30-60 seconds)
- Criteria: Strong hooks, emotional peaks, quotable moments
- Output: JSON array with score, quote, timestamps, reasoning
```

---

## Phase 4: YouTube Download Integration

**Goal:** Paste YouTube URL → yt-dlp downloads → feeds into existing pipeline.

### Tasks

```
4.1 Bundle yt-dlp binary
    - Download standalone binary (not Python)
    - Add to Resources/
    - Sign with Developer ID

4.2 Download service
    - DownloadService actor
    - Run yt-dlp via Process
    - Parse progress from stdout
    - Extract video metadata (title, duration)

4.3 URL validation
    - Detect supported platforms (YouTube, Vimeo, etc.)
    - Show inline error for unsupported URLs
    - Auto-paste from clipboard on window focus

4.4 yt-dlp update mechanism
    - Check for updates weekly
    - Download to Application Support
    - Use updated version if available

4.5 Connect to pipeline
    - URL input → Download → Transcribe → Analyze
    - Show all three phases in progress UI
```

### Test Checkpoint

```
✓ Paste YouTube URL → validation passes
✓ Invalid URL shows error inline
✓ Download progress shows percentage
✓ Video title appears during download
✓ After download → transcription starts automatically
✓ Full pipeline: URL → clips suggestions
✓ yt-dlp update check works (can be mocked)
```

### Files to Create

```
Sources/
├── Services/
│   ├── DownloadService.swift
│   └── YTDLPUpdater.swift
├── Models/
│   └── VideoMetadata.swift
├── Views/
│   └── URLInputField.swift
Resources/
└── yt-dlp                        (bundled binary)
```

### yt-dlp Commands

```bash
# Download best quality
yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
       --merge-output-format mp4 \
       -o "%(title)s.%(ext)s" \
       "URL"

# Get metadata only
yt-dlp --dump-json "URL"

# Progress parsing regex
# [download]  45.2% of 1.20GiB at 5.43MiB/s ETA 01:45
```

---

## Phase 5: Face Detection & Tracking

**Goal:** Analyze video frames → detect faces → generate smooth tracking data.

### Tasks

```
5.1 Vision framework integration
    - FaceTrackingService actor
    - VNDetectFaceRectanglesRequest
    - Sample every 10 frames (configurable)

5.2 Face position model
    - FaceFrame struct (timestamp, boundingBox)
    - [FaceFrame] array per video

5.3 Smoothing algorithm
    - Implement basic easing between positions
    - Handle face disappearing/reappearing
    - Multi-face: track largest or zoom out

5.4 Crop keyframe generation
    - Convert face positions to crop rectangles
    - Center face in 9:16 frame
    - Output: [CropKeyframe] for FFmpeg

5.5 Run parallel with AI analysis
    - Face detection runs while GPT analyzes
    - Both complete before showing results
```

### Test Checkpoint

```
✓ Face detection runs on local video
✓ Progress reported during detection
✓ Face positions JSON saved (for debugging)
✓ Smoothing reduces jitter between frames
✓ Handles video with no faces (graceful fallback)
✓ Handles multiple faces
✓ Runs in parallel with GPT analysis
```

### Files to Create

```
Sources/
├── Services/
│   └── FaceTrackingService.swift
├── Models/
│   ├── FaceFrame.swift
│   └── CropKeyframe.swift
├── Utils/
│   └── SmoothingAlgorithm.swift
```

### Vision Framework Code Pattern

```swift
let request = VNDetectFaceRectanglesRequest()
let handler = VNImageRequestHandler(cgImage: frame)
try handler.perform([request])

if let results = request.results {
    for face in results {
        // face.boundingBox is normalized (0-1)
        // Convert to pixel coordinates
    }
}
```

---

## Phase 6: Export Engine

**Goal:** Selected clips → FFmpeg exports with 9:16 crop following speaker.

### Tasks

```
6.1 Bundle FFmpeg binary
    - Download static build
    - Add to Resources/
    - Sign with Developer ID

6.2 Export service
    - ExportService actor
    - Run FFmpeg via Process
    - Parse progress from stderr

6.3 Crop filter generation
    - Convert CropKeyframes to FFmpeg filter
    - Use zoompan or crop filter with keyframes
    - Maintain aspect ratio

6.4 Export settings panel
    - Format: 9:16, 1:1, 16:9
    - Quality: 720p, 1080p, 4K
    - Output location picker

6.5 Floating export panel
    - Progress per clip
    - Floating above other windows
    - Completion state with thumbnails
    - "Show in Finder" / "Share..." buttons

6.6 Drag-and-drop export
    - Thumbnails draggable to Finder/apps
    - NSItemProvider for drag data
```

### Test Checkpoint

```
✓ Single clip exports to 9:16
✓ Speaker tracking applied (face stays centered)
✓ Multiple clips export in sequence
✓ Progress shown per clip
✓ Floating panel appears during export
✓ "Show in Finder" opens correct folder
✓ Thumbnails draggable to other apps
✓ Export settings persist
```

### Files to Create

```
Sources/
├── Services/
│   └── ExportService.swift
├── Models/
│   └── ExportSettings.swift
├── Views/
│   ├── ExportSettingsPanel.swift
│   └── FloatingExportPanel.swift
├── Utils/
│   └── FFmpegFilterBuilder.swift
Resources/
└── ffmpeg                        (bundled binary)
```

### FFmpeg Commands

```bash
# Basic 9:16 center crop
ffmpeg -i input.mp4 \
       -vf "crop=ih*9/16:ih,scale=1080:1920" \
       -c:a copy output.mp4

# With dynamic crop (keyframes)
ffmpeg -i input.mp4 \
       -vf "crop=w:h:x:y" \
       -c:a copy output.mp4

# Progress parsing (from stderr)
# frame= 1234 fps=60 ... time=00:00:41.00 ...
```

---

## Phase 7: Polish & Production Ready

**Goal:** Error handling, persistence, edge cases, final UI polish.

### Tasks

```
7.1 Error handling
    - User-friendly error messages
    - Retry options where applicable
    - Offline mode detection

7.2 Project persistence
    - Save/load projects to ~/Library/Application Support/
    - Recent projects in menu bar
    - Re-export without re-analyzing

7.3 Trim adjustment UI
    - TrimPopover with waveform
    - Drag handles for start/end
    - Duration warning (>60s)

7.4 Storage management
    - Track cache usage
    - Auto-delete downloads after export (optional)
    - Manual clear buttons in Settings

7.5 Keyboard shortcuts
    - Space: play/pause
    - ↑/↓: navigate clips
    - E: toggle export
    - ⌘↵: export selected

7.6 Menu bar status
    - Show processing indicator
    - Offline indicator
    - Recent clips quick access

7.7 First-launch experience
    - Onboarding if needed (probably skip)
    - API key setup prompt
    - Model download prompt

7.8 Final testing
    - Various video lengths (5min, 30min, 2hr)
    - Different content types (podcast, interview, vlog)
    - Edge cases (no faces, multiple speakers, poor audio)
```

### Test Checkpoint

```
✓ All error states show friendly messages
✓ Projects save and reload correctly
✓ Trim UI adjusts clip boundaries
✓ Keyboard shortcuts all work
✓ App works offline (local files only)
✓ Storage can be cleared
✓ 2-hour video processes successfully
✓ App feels snappy and polished
```

### Files to Create/Update

```
Sources/
├── Services/
│   ├── ProjectManager.swift
│   └── StorageManager.swift
├── Models/
│   └── Project.swift
├── Views/
│   ├── TrimPopover.swift
│   ├── WaveformView.swift
│   ├── StorageSettingsView.swift
│   └── OnboardingView.swift      (if needed)
```

---

## Dependency Checklist

### Swift Packages (SPM)

```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
]
```

### Bundled Binaries

| Binary | Source | Size |
|--------|--------|------|
| yt-dlp | [GitHub Releases](https://github.com/yt-dlp/yt-dlp/releases) | ~22 MB |
| ffmpeg | [evermeet.cx](https://evermeet.cx/ffmpeg/) | ~80 MB |

### Build Script (Pre-Archive)

```bash
#!/bin/bash
# scripts/bundle-binaries.sh

# Download yt-dlp
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o Resources/yt-dlp
chmod +x Resources/yt-dlp

# Download ffmpeg (or use local copy)
# curl -L ... -o Resources/ffmpeg

# Sign binaries
codesign --force --sign "Developer ID Application: YOUR NAME" Resources/yt-dlp
codesign --force --sign "Developer ID Application: YOUR NAME" Resources/ffmpeg
```

---

## Testing Strategy

### Unit Tests

```
- TranscriptionService: mock WhisperKit, verify output format
- AnalysisService: mock GPT response, verify parsing
- FaceTrackingService: test smoothing algorithm
- FFmpegFilterBuilder: verify filter string generation
```

### Integration Tests

```
- Full pipeline with short test video (30 sec)
- YouTube download with known stable URL
- Export produces valid MP4
```

### Manual Test Matrix

| Test Case | Phase |
|-----------|-------|
| Short video (30s) local | 2 |
| Long video (2hr) local | 2, 7 |
| Poor audio quality | 2 |
| Non-English audio | 2 |
| YouTube standard video | 4 |
| YouTube age-restricted | 4 |
| YouTube private video (should fail gracefully) | 4 |
| Video with no faces | 5 |
| Video with multiple speakers | 5 |
| Podcast (audio-only faces) | 5 |
| Export 1 clip | 6 |
| Export 10 clips | 6 |
| Disk full during export | 6, 7 |
| Offline mode | 7 |
| Kill app during processing | 7 |

---

## Timeline Estimate

**Not providing time estimates** - depends on your availability and familiarity with Swift/SwiftUI. Each phase is a logical checkpoint where you can pause, test, and validate before continuing.

**Suggested approach:**
1. Complete Phase 1-2 first (foundation + transcription)
2. Validate the core works well
3. Continue phases sequentially
4. Phase 5-6 can be parallelized if needed

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| yt-dlp breaks with YouTube | Auto-update mechanism, bundled fallback |
| WhisperKit performance issues | Model selection, progress feedback |
| GPT API costs spike | Show estimated cost, usage warnings |
| Face tracking jittery | Smoothing algorithm, fallback to center |
| App notarization fails | Sign all binaries, test early |
| Large video memory issues | Stream processing, chunk analysis |
