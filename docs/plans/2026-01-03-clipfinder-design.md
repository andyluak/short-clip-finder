# ClipFinder - Design Document

**Date:** 2026-01-03
**Status:** Approved
**Author:** Alexandru Tirim + Claude

---

## Overview

ClipFinder is a native macOS menu bar application that finds viral-worthy short-form clips from YouTube videos and podcasts. Users paste a URL or drop a local file, and AI analyzes the transcript to suggest the best clips with timestamps. One-click export with auto speaker tracking and 9:16 crop.

### Value Proposition

- **Gap:** OpusClip, Klap, quso.ai are all web-based with slow processing
- **Differentiator:** Native Mac app with local Whisper transcription = faster + private
- **Pricing target:** $15/mo or $99/year

### Competitors

| Competitor | Type | Price |
|------------|------|-------|
| [OpusClip](https://www.opus.pro/) | Web | $15/mo |
| [Klap](https://klap.app/) | Web | $15-49/mo |
| [quso.ai](https://quso.ai/) | Web | $19-49/mo |

---

## Core Technology Stack

| Component | Solution | Notes |
|-----------|----------|-------|
| **Transcription** | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Native Swift, Apple Silicon optimized, CoreML |
| **Video Download** | [yt-dlp](https://github.com/yt-dlp/yt-dlp) | CLI tool, 1700+ sites. Bundled binary |
| **Video Editing** | [FFmpeg](https://ffmpeg.org/) | Crop, encode, 9:16 conversion. Bundled binary |
| **AI Analysis** | OpenAI GPT-4o/GPT-5 API | Analyze transcript for viral moments |
| **Speaker Tracking** | [Apple Vision Framework](https://developer.apple.com/documentation/vision) | Native face detection, on-device |

---

## UX Design

### Three Surfaces

**1. Menu Bar Icon + Dropdown**
```
┌─────────────────────────────┐
│ 🎬 ▾                        │  ← Menu bar icon
├─────────────────────────────┤
│ ⌘N  New from URL...        │
│ ⌘O  New from File...       │
│ ─────────────────────────── │
│ ⏳ Processing: podcast.mp4  │  ← Live status
│ ─────────────────────────── │
│ Recent:                     │
│   → Marketing Talk (5 clips)│
│   → Podcast Ep 42 (3 clips) │
│ ─────────────────────────── │
│ ⌘,  Settings                │
│ ⌘Q  Quit ClipFinder         │
└─────────────────────────────┘
```

**2. Main Window** - The work surface (~800x600, resizable)

**3. Floating Export Panel** - CleanShot-style progress/completion

---

### Main Window States

**State 1: Empty / Input**
```
┌──────────────────────────────────────────────────────────────┐
│  ClipFinder                                        ─  □  ✕  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                     🎬                                       │
│                                                              │
│         Paste a YouTube URL or drop a video file            │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ https://youtube.com/watch?v=...                    📋  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│                  [ Find Viral Clips ]                        │
│                                                              │
│  ─────────────────────────────────────────────────────────  │
│  💡 Tip: Works with YouTube, Vimeo, podcasts, local MP4     │
└──────────────────────────────────────────────────────────────┘
```

**State 2: Processing**
```
┌──────────────────────────────────────────────────────────────┐
│  ClipFinder                                        ─  □  ✕  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  📺 Joe Rogan #2045 - Naval Ravikant                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━░░░░░░  68%     │
│                                                              │
│  ✓ Downloaded video                              2.1 GB     │
│  ✓ Transcribed audio                             1:42:33    │
│  ◉ Finding viral moments...                      ~30 sec    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ░░░░░░░▓▓▓░░░░░░░░▓▓▓▓▓░░░░░░░▓▓░░░░░░▓▓▓▓░░░░░░░░░  │ │
│  │  ↑ AI is identifying high-engagement segments          │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│                      [ Cancel ]                              │
└──────────────────────────────────────────────────────────────┘
```

**State 3: Clip Selection**
```
┌──────────────────────────────────────────────────────────────────────────┐
│  ClipFinder                                                    ─  □  ✕  │
├──────────────────────────────────────────────────────────────────────────┤
│  📺 Joe Rogan #2045 - Naval Ravikant                    [ Export All 5 ]│
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ ▶ thumbnail frame          │  🔥 92  │ "Happiness is a choice"     ││
│  │   [━━━━━░░░░░]  0:45       │ VIRAL   │                              ││
│  │   ├────────────────────────┼─────────┼─────────────────────────────┤││
│  │   │ 14:32 → 15:17          │  45s    │ ☑ Export    ⚙ Trim          │││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ ▶ thumbnail frame          │  🔥 87  │ "Money won't solve your     ││
│  │   [━━━░░░░░░░]  0:38       │ HIGH    │  money problems"            ││
│  │   ├────────────────────────┼─────────┼─────────────────────────────┤││
│  │   │ 42:15 → 42:53          │  38s    │ ☑ Export    ⚙ Trim          │││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  Selected: 3 clips  │  Total: 2:15  │  [ Export Selected → ]           │
└──────────────────────────────────────────────────────────────────────────┘
```

**Keyboard Shortcuts:**
- `Space` - Play/pause selected clip
- `↑/↓` - Navigate clips
- `E` - Toggle export checkbox
- `⌘↵` - Export selected

---

### Trim Popover

```
┌─────────────────────────────────────────────────────────────┐
│  Trim Clip                                              ✕   │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    ▶ VIDEO PREVIEW                    │  │
│  │                       [9:16]                          │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ◀│░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░│▶             │  │
│  │   ↑ drag handles                    ↑                 │  │
│  │  14:27                           15:22                │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│   Duration: 55s        Max recommended: 60s                 │
│                                                             │
│              [ Cancel ]    [ Save Trim ]                    │
└─────────────────────────────────────────────────────────────┘
```

---

### Export Settings Panel

```
┌────────────────────────────────────────┐
│  Export Settings                    ✕  │
├────────────────────────────────────────┤
│                                        │
│  Format                                │
│  ◉ 9:16 Vertical (TikTok/Reels/Shorts) │
│  ○ 1:1 Square (Instagram)              │
│  ○ 16:9 Original                       │
│                                        │
│  Quality                               │
│  ○ 1080p (recommended)                 │
│  ○ 720p (smaller files)                │
│  ○ 4K (if source supports)             │
│                                        │
│  Crop Focus                            │
│  ◉ Auto-detect speaker                 │
│  ○ Center crop                         │
│  ○ Manual (set per clip)               │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 📁 ~/Desktop/ClipFinder Exports  │  │
│  └──────────────────────────────────┘  │
│                                        │
│        [ Export 3 Clips → ]            │
│                                        │
└────────────────────────────────────────┘
```

---

### Floating Export Panel

```
┌─────────────────────────────────────────┐
│  Exporting 3 clips...              ✕    │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────┐  Clip 1 of 3                   │
│  │ 🎬  │  ━━━━━━━━━━━━━━━━━━━░░  87%    │
│  └─────┘  "Happiness is a choice"       │
│                                         │
│  Remaining: ~45 seconds                 │
│                                         │
└─────────────────────────────────────────┘

        ↓ (on complete)

┌─────────────────────────────────────────┐
│  ✓ 3 clips exported                 ✕   │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────┐ ┌─────┐ ┌─────┐               │
│  │ ▶  │ │ ▶  │ │ ▶  │               │
│  └─────┘ └─────┘ └─────┘               │
│                                         │
│  [ Show in Finder ]  [ Share... ]       │
│                                         │
└─────────────────────────────────────────┘
```

- Floats above all windows
- Draggable, dismissable
- Thumbnails are draggable to Finder, Premiere, etc.

---

## Technical Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           ClipFinder.app                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │   SwiftUI    │    │   Services   │    │   External   │              │
│  │     Views    │◄──►│    Layer     │◄──►│  Processes   │              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│         │                   │                   │                       │
│         ▼                   ▼                   ▼                       │
│  ┌────────────┐      ┌────────────┐      ┌────────────┐                │
│  │ MenuBar    │      │ Download   │      │  yt-dlp    │                │
│  │ MainWindow │      │ Service    │──────│  (binary)  │                │
│  │ ClipCards  │      ├────────────┤      ├────────────┤                │
│  │ TrimView   │      │ Transcribe │      │ WhisperKit │                │
│  │ ExportPanel│      │ Service    │──────│  (Swift)   │                │
│  └────────────┘      ├────────────┤      ├────────────┤                │
│                      │ AI Analyze │      │  GPT API   │                │
│                      │ Service    │──────│  (REST)    │                │
│                      ├────────────┤      ├────────────┤                │
│                      │ FaceTrack  │      │  Vision    │                │
│                      │ Service    │──────│ Framework  │                │
│                      ├────────────┤      ├────────────┤                │
│                      │ Export     │      │  FFmpeg    │                │
│                      │ Service    │──────│  (binary)  │                │
│                      └────────────┘      └────────────┘                │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        Local Storage                             │   │
│  │  ~/Library/Application Support/ClipFinder/                       │   │
│  │  ├── downloads/        (temp video files)                        │   │
│  │  ├── transcripts/      (JSON with word timestamps)               │   │
│  │  ├── projects/         (saved sessions)                          │   │
│  │  └── exports/          (default output)                          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Pipeline

```
URL/File
    │
    ▼
┌─────────────────┐
│ 1. DOWNLOAD     │  yt-dlp → best quality MP4
│    ~2-5 min     │  (skip if local file)
└────────┬────────┘
         │ video.mp4
         ▼
┌─────────────────┐
│ 2. TRANSCRIBE   │  WhisperKit (local, Apple Silicon)
│    ~0.5x real   │  Output: words[] with timestamps
└────────┬────────┘
         │ transcript.json
         ▼
┌─────────────────┐
│ 3. ANALYZE      │  GPT-4o API
│    ~10-30 sec   │  Input: transcript + "find viral moments"
└────────┬────────┘  Output: clips[] with scores + hooks
         │
         ▼
┌─────────────────┐
│ 4. FACE DETECT  │  Vision framework (parallel with step 3)
│    ~1x real     │  Output: face_positions[] per frame
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 5. USER PICKS   │  UI: select clips, adjust trims
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 6. EXPORT       │  FFmpeg: crop + scale + encode
│    ~0.3x real   │  Output: clip_01.mp4, clip_02.mp4...
└─────────────────┘
```

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Bundled binaries** | yt-dlp + FFmpeg included | No user install steps |
| **Transcription** | WhisperKit (not CLI) | Native Swift, no Python |
| **Concurrency** | Swift async/await + Actors | Modern, safe |
| **State management** | @Observable (macOS 14+) | Simpler than Combine |
| **Face tracking** | Sample every 10 frames | Balance speed/accuracy |

---

## Speaker Detection (Critical Feature)

### Approach: Apple Vision + Custom Smoothing

```
Frame 1    Frame 30    Frame 60    Frame 90
  👤         👤           👤          👤
  ↓          ↓            ↓           ↓
[detect]  [detect]    [detect]    [detect]
  ↓          ↓            ↓           ↓
     └──► Kalman filter / easing ◄──┘
                    ↓
         Smooth crop keyframes
```

- Run `VNDetectFaceRectanglesRequest` every N frames
- Apply smoothing (Kalman filter or easing) to avoid jarring jumps
- Generate crop keyframes → FFmpeg applies at export
- **Multi-speaker:** Detect multiple faces, zoom out or track active speaker via audio

### Why This Approach

| Option | Pros | Cons |
|--------|------|------|
| **Apple Vision** | Native, on-device, private, free | Build tracking logic |
| Google AutoFlip | Battle-tested | C++, needs bridging |
| Custom ML | Full control | Training data needed |

**Decision:** Apple Vision + custom smoothing. 100% local, no API costs.

---

## Dependencies & Bundling

### App Bundle Structure

```
ClipFinder.app/
└── Contents/
    ├── MacOS/
    │   └── ClipFinder              (main executable)
    ├── Resources/
    │   ├── yt-dlp                  (bundled binary, ~22 MB)
    │   ├── ffmpeg                  (bundled binary, ~80 MB)
    │   └── Assets.xcassets
    ├── Frameworks/
    │   └── WhisperKit.framework    (via SPM)
    └── Info.plist
```

### WhisperKit Model Download

First-launch prompt to download models:
- **Tiny (75 MB)** - Fast, good for clear audio
- **Base (150 MB)** - Balanced (recommended)
- **Large-v3 (500 MB)** - Best accuracy

Models stored in `~/Library/Application Support/ClipFinder/models/`

### yt-dlp Update Strategy

YouTube breaks frequently. **Hybrid approach:**
- Bundle known-good version
- Check for updates weekly
- Download to Application Support (not bundle)
- Use updated version if available, fall back to bundled

```swift
func ytdlpPath() -> URL {
    let updated = appSupport.appendingPathComponent("yt-dlp")
    if FileManager.default.fileExists(atPath: updated.path) {
        return updated
    }
    return Bundle.main.url(forResource: "yt-dlp", withExtension: nil)!
}
```

### Signing & Notarization

All bundled binaries must be signed for notarization:

```bash
codesign --force --sign "Developer ID" yt-dlp
codesign --force --sign "Developer ID" ffmpeg
notarytool submit ClipFinder.app
stapler staple ClipFinder.app
```

---

## Error Handling

| Error | Cause | UX Response |
|-------|-------|-------------|
| Download failed | yt-dlp blocked, private video | Toast + retry option |
| Unsupported URL | Not supported platform | Inline validation |
| Transcription failed | Corrupt audio | "Try a different file" |
| API rate limit | GPT quota exceeded | Queue, show "queued" |
| API key invalid | Expired/wrong key | Open Settings |
| No faces detected | Screen recording, no people | Fall back to center crop |
| Export failed | Disk full, permissions | Specific error + action |
| Offline | No internet | Show cached, disable URL |

### Graceful Degradation

When no faces detected:
```
⚠️ Couldn't detect any faces in this video

Speaker tracking won't be available.
Videos will be center-cropped instead.

[ Use Center Crop ]    [ Cancel Export ]
```

### Offline Mode

```swift
// Offline capabilities:
✓ Open saved projects
✓ Re-export previously analyzed clips
✓ Transcribe local files (WhisperKit is local)
✓ Face detection (Vision is local)

✗ Download from URL
✗ AI clip analysis (needs GPT API)
```

---

## Settings

### API Keys
- Stored in macOS Keychain (not UserDefaults)
- Validate on entry
- Show estimated cost per video

### Export Defaults
- Format: 9:16 / 1:1 / 16:9
- Quality: 720p / 1080p / 4K
- Crop mode: Auto-track / Center
- Output location
- File naming template

### Storage Management
- Cache usage visualization
- Auto-delete downloads after export
- Cache limit setting

---

## MVP Scope

### In Scope (v1)
- Menu bar app with main window
- YouTube + local file input
- WhisperKit transcription (local)
- GPT-4o clip analysis (cloud)
- Apple Vision face detection
- 9:16 crop with speaker tracking
- Basic export (no captions)

### Out of Scope (v2+)
- Hormozi-style animated captions
- Multi-language dubbing
- Social media scheduling
- Team collaboration
- Windows/Linux versions

---

## Open Questions

1. **Pricing implementation** - Stripe? RevenueCat? In-app purchase?
2. **Free tier limits** - How many clips/month?
3. **Analytics** - What to track? Privacy-respecting options?

---

## Resources

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - Swift Whisper implementation
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Video downloader
- [Apple Vision](https://developer.apple.com/documentation/vision) - Face detection
- [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) - Menu bar API
- [WWDC24 Vision](https://developer.apple.com/videos/play/wwdc2024/10163/) - Swift enhancements
