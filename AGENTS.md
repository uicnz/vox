# Vox – Dev Notes for Agents

This file provides guidance for coding agents working in this repo.

## Project Overview

Vox is a macOS menu bar application for on-device voice-to-text. It supports
Nemotron ASR and Parakeet TDT via FluidAudio. WhisperKit remains linked for
legacy Whisper models, but Whisper is deprecated and should not be treated as
the default path. Users activate transcription with hotkeys; text can be
auto-pasted into the active app.

## Build & Development Commands

```bash
# Build the app
xcodebuild -scheme Vox -configuration Release

# Run tests (must be run from VoxCore directory for unit tests)
cd VoxCore && swift test

# Or run all tests via Xcode
xcodebuild test -scheme Vox

# Open in Xcode (recommended for development)
open Vox.xcodeproj
```

## Architecture

The app uses **The Composable Architecture (TCA)** for state management. Key
architectural components:

### Features (TCA Reducers)

- `AppFeature`: Root feature coordinating the app lifecycle
- `TranscriptionFeature`: Core recording and transcription logic
- `SettingsFeature`: User preferences and configuration
- `HistoryFeature`: Transcription history management

### Dependency Clients

- `TranscriptionClient`: FluidAudio and legacy WhisperKit transcription
- `RecordingClient`: AVAudioRecorder wrapper for audio capture
- `PasteboardClient`: Clipboard operations
- `KeyEventMonitorClient`: Global hotkey monitoring via Sauce framework

### Key Dependencies

- **FluidAudio (Nemotron + Parakeet)**: Native Core ML ASR model families
- **WhisperKit**: Legacy Core ML Whisper support pending deprecation
- **Sauce**: Keyboard event monitoring
- **Sparkle**: Auto-updates from the latest GitHub release `appcast.xml`
- **Swift Composable Architecture**: State management
- **Inject** Hot Reloading for SwiftUI

## Important Implementation Details

1. **Hotkey Recording Modes**: The app supports both press-and-hold and
   double-tap recording modes, implemented in `HotKeyProcessor.swift`. See
   `docs/hotkey-semantics.md` for detailed behavior specifications including:
   - **Modifier-only hotkeys** (e.g., Option) use a **0.3s threshold** to
     prevent accidental triggers from OS shortcuts
   - **Regular hotkeys** (e.g., Cmd+A) use user's `minimumKeyTime` setting
     (default 0.2s)
   - Mouse clicks and extra modifiers are discarded within threshold, ignored after
   - Only ESC cancels recordings after the threshold

2. **Model Management**: Models are managed by `ModelDownloadFeature`. Curated
   defaults live in `Vox/Resources/Data/models.json`. Nemotron ASR is the
   default and appears first. Parakeet remains available as a native
   FluidAudio option. Whisper options are legacy and stay behind "Show more"
   until they are removed. No dropdowns.

3. **Sound Effects**: Audio feedback is provided via `SoundEffect.swift` using
   files in `Resources/Audio/`

4. **Window Management**: Uses an `InvisibleWindow` for the transcription
   indicator overlay

5. **Permissions**: Requires audio input and automation entitlements (see `Vox.entitlements`)

6. **Logging**: All diagnostics should use the unified logging helper `VoxLog`
   (`VoxCore/Sources/VoxCore/Logging.swift`). Pick an existing category (e.g.,
   `.transcription`, `.recording`, `.settings`) or add a new case so Console
   predicates stay consistent. Avoid `print` and prefer privacy annotations
   (`, privacy: .private`) for anything potentially sensitive like transcript
   text or file paths.

## Models (2025‑11)

- First-run default: Nemotron 3.5 ASR full multilingual via FluidAudio
- Additional curated FluidAudio models: Parakeet TDT v2 and Parakeet TDT v3
- Legacy Whisper models behind "Show more": Whisper Small (Tiny), Whisper
  Medium (Base), and Whisper Large v3
- Note: Distil-Whisper is English-only and not shown by default. Whisper models
  are deprecated and expected to be removed in a future version.

### Storage Locations

- Legacy WhisperKit models
  - `~/Library/Application Support/nz.uic.vox/models/argmaxinc/whisperkit-coreml/<model>`
- FluidAudio ASR models
  - We set `XDG_CACHE_HOME` on launch so FluidAudio caches under the app container:
  - `~/Library/Containers/nz.uic.vox/Data/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml`
  - `~/Library/Containers/nz.uic.vox/Data/Library/Application Support/FluidAudio/Models/nemotron-multilingual/multilingual/2240ms`
  - Legacy `~/.cache/fluidaudio/Models/…` is not visible to the sandbox;
    re-download or import.

### Progress + Availability

- Nemotron: FluidAudio download progress
- Parakeet: best-effort progress by polling the model directory size during
  download
- WhisperKit: native progress for legacy Whisper models
- Availability detection scans both `Application Support/FluidAudio/Models` and
  our app cache path

## Building & Running

- macOS 14+, Xcode 15+

### Packages

- WhisperKit: `https://github.com/argmaxinc/WhisperKit`
- FluidAudio: `https://github.com/FluidInference/FluidAudio.git`
  (link `FluidAudio` to Vox target)

### Entitlements (Sandbox)

- `com.apple.security.app-sandbox = true`
- `com.apple.security.network.client = true` (HF downloads)
- `com.apple.security.files.user-selected.read-write = true` (optional import)
- `com.apple.security.automation.apple-events = true` (media control)

### Cache root (FluidAudio)

Set at app launch and logged:

```INI
XDG_CACHE_HOME = ~/Library/Containers/nz.uic.vox/Data/Library/Application Support/nz.uic.vox/cache
```

FluidAudio models reside under `Application Support/FluidAudio/Models`.

## UI

- Settings -> Transcription Model shows a compact list with radio selection,
  accuracy/speed dots, size on right, and trailing menu / download-check icon.
- Context menu offers Show in Finder / Delete.

## Troubleshooting

- Repeated mic prompts during debug: ensure Debug signing uses
  "Apple Development" so TCC sticks
- Sandbox network errors (-1003): add
  `com.apple.security.network.client = true` (already set)
- FluidAudio model not detected: ensure it resides under the container path
  above; downloading from Vox places it correctly.

## Git Commit Messages

- Use a concise, descriptive subject line that captures the user-facing impact
  (roughly 50-70 characters).
- Follow up with as much context as needed in the body. Include the rationale,
  notable tradeoffs, relevant logs, or reproduction steps. Future debugging
  benefits from having the full story directly in git history.
- Reference any related GitHub issues in the body if the change tracks ongoing work.

## Releasing a New Version

Releases are automated via the local build tool, which handles building,
signing, notarizing, appcast generation, and GitHub release uploads.

### Prerequisites

1. **GitHub CLI authentication** must be available for release uploads:

   ```bash
   gh auth login
   ```

2. **Notarization credentials** stored in keychain (one-time setup):

   ```bash
   xcrun notarytool store-credentials "aria-notarytool"
   ```

3. **Dependencies installed** at project root:

   ```bash
   bun install
   ```

### Release Steps

1. **Ensure version metadata and release changes are committed** before publishing

2. **Run the release command** from project root:

   ```bash
   bun run release
   ```

### What the Release Tool Does

1. Builds `Vox.app` with xcodebuild
2. Signs embedded code and the app with Developer ID
3. Notarizes and staples the app with Apple
4. Creates a ZIP archive containing the stapled app
5. Creates, notarizes, and staples a DMG
6. Copies the DMG into `build/updates`
7. Generates Sparkle `appcast.xml` with versioned GitHub release asset URLs
8. Creates or updates the versioned GitHub release
9. Uploads `appcast.xml`, DMG, ZIP, and `vox-latest.dmg` attachments

### Artifacts

Each release produces:

- `Vox-{version}-{build}.dmg` - Notarized DMG containing the signed app
- `Vox-{version}-{build}.zip` - For Homebrew cask
- `vox-latest.dmg` - Always points to latest
- `appcast.xml` - Sparkle update feed

### Additional Troubleshooting

- **"Working tree is not clean"**: Commit or stash all changes before releasing
- **Notarization fails**: Check Apple ID credentials and app-specific password
- **GitHub upload fails**: Run `gh auth status` and verify release write access
- **Build fails**: Ensure Xcode 16+ and valid code signing certificates
