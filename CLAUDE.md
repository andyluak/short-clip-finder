# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the app
xcodebuild -project short-clip-finder/short-clip-finder.xcodeproj -scheme short-clip-finder -configuration Debug build

# Build and run
open short-clip-finder/short-clip-finder.xcodeproj  # Then Cmd+R in Xcode

# Clean build
xcodebuild -project short-clip-finder/short-clip-finder.xcodeproj -scheme short-clip-finder clean
```

## Architecture

**ClipFinder** is a macOS menu bar app that finds viral-worthy clips in long-form videos. It runs as a menu bar app (no Dock icon) with a main window for the UI.

### Processing Pipeline

The app follows a 4-stage async pipeline managed by `AppState`:

1. **Download** (`DownloadService`) - Downloads videos from YouTube/Vimeo using bundled `yt-dlp` binary
2. **Transcribe** (`TranscriptionService`) - Extracts audio and transcribes using WhisperKit (distil-large-v3 model)
3. **Analyze** (`AnalysisService`) - Sends transcript to GPT-4o to identify 30-90 second viral clip candidates
4. **Export** (`ExportService`) - Cuts clips with `ffmpeg`, optionally tracking faces for 9:16 crop

### Key Services (all `actor` types for thread safety)

- `DownloadService` - Wraps yt-dlp Process, parses progress from stdout
- `TranscriptionService` - WhisperKit integration, extracts audio via AVAssetExportSession
- `AnalysisService` - OpenAI API with structured JSON schema output, retry logic
- `ExportService` - FFmpeg wrapper with face-tracking crop filters
- `FaceTrackingService` - Vision framework VNDetectFaceRectanglesRequest, smoothing algorithm
- `ProjectManager` - Persists projects to ~/Library/Application Support/ClipFinder/

### State Management

`AppState` is an `@Observable` `@MainActor` class that:
- Holds current screen state (`empty`/`processing`/`results`)
- Orchestrates the pipeline via async tasks
- Manages clip selection, export settings, and recent projects

### External Dependencies

- **WhisperKit** (SPM) - On-device speech recognition
- **yt-dlp** (bundled binary) - Video downloading from 1000+ sites
- **ffmpeg** (bundled binary) - Video encoding/cropping

Binaries are in `short-clip-finder/short-clip-finder/Resources/`. The services check:
1. `~/Library/Application Support/ClipFinder/` (for auto-updates)
2. Bundle resources (production)
3. Source Resources folder (development)

### API Keys

OpenAI API key is stored in Keychain via `KeychainManager`. Settings window allows entry and validation.
