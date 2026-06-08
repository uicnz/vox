# Vox

> Voice → Text

Press-and-hold a hotkey to transcribe your voice and paste the result wherever
you're typing.

**[Download Vox for macOS](https://github.com/uicnz/vox/releases/download/sparkle/vox-latest.dmg)**

> **Note:** Vox is currently only available for **Apple Silicon** Macs.

Or download via Homebrew:

```bash
brew install --cask uicnz/vox/aria-vox
```

## Instructions

Once you open Vox, you'll need to grant it microphone and accessibility
permissions—so it can record your voice and paste the transcribed text into any
application, respectively.

Once you've configured a global hotkey, there are **two recording modes**:

1. **Press-and-hold** the hotkey to begin recording, say whatever you want, and
   then release the hotkey to start the transcription process.
2. **Double-tap** the hotkey to *lock recording*, say whatever you want, and
   then **tap** the hotkey once more to start the transcription process.

### Signed local builds

Vox has an Aria-style local build command for Developer ID signing and Apple
notarization:

```bash
bun run build:release
```

Use `bun run build:install` to build, sign, notarize, staple, verify, and copy
the app to `/Applications/Vox.app`. For signing-only local checks without Apple
notarization, use `bun run build:app`.

### Releases

`bun run release` publishes the current version to GitHub Releases and Sparkle.
Update version metadata before running it.

## License

This project is licensed under the MIT License. See `LICENSE` for details.

## Acknowledgements

Kit Langton Is the original author of this app. The only reason this version
exists is I wanted to add my own models and tweaks.
