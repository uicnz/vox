# Vox Release Process

## Overview

Releases are published entirely through GitHub:

- Builds and Developer ID signs the app
- Notarizes and staples `Vox.app`
- Creates ZIP and DMG artifacts
- Notarizes and staples the DMG
- Generates the Sparkle `appcast.xml`
- Creates or updates the versioned GitHub Release
- Uploads `appcast.xml`, DMG, ZIP, and `vox-latest.dmg`

Sparkle checks this stable feed URL:

```text
https://raw.githubusercontent.com/uicnz/vox/main/docs/appcast.xml
```

The public latest-download URL remains attached to the versioned release:

```text
https://github.com/uicnz/vox/releases/download/v0.1.2/vox-latest.dmg
```

## Quick Start

```bash
bun run release
```

By default this publishes:

- Sparkle feed file to `docs/appcast.xml`
- User-facing assets to tag `v<package.json version>`
- Appcast enclosure URLs that point at that same versioned release

Override the repository or versioned tag when needed:

```bash
bun run tools/src/build.ts --publish-github \
  --github-repo=owner/repo \
  --github-release-tag=v0.8.0
```

## Required Tools

```bash
bun install
gh auth login
xcrun notarytool store-credentials "aria-notarytool"
```

The GitHub CLI account must have permission to create releases and upload
release assets.

## Required Secrets

### Apple Notarization

Local releases use the keychain profile configured above. CI can provide
equivalent Apple notarization credentials if the workflow writes them into a
notarytool profile before running the release script.

### Code Signing

The Developer ID Application certificate must be available in the keychain used
by the build:

```text
Developer ID Application: Shane Holloman (N68C9LUA5B)
```

### Sparkle Signing

For local releases, Sparkle can read the private EdDSA key from the keychain.
In CI, provide the key through one of:

```bash
SPARKLE_PRIVATE_KEY=... bun run release
SPARKLE_ED_PRIVATE_KEY=... bun run release
bun run tools/src/build.ts --publish-github \
  --sparkle-ed-key-file=/path/to/private-key
```

The public key in `Vox/Info.plist` must match the private key used by the
Sparkle `generate_appcast` tool resolved from SwiftPM/Xcode package artifacts.

## Artifacts

Each release produces:

- `build/artifacts/Vox-{version}-{build}.dmg`
- `build/artifacts/Vox-{version}-{build}.zip`
- `build/artifacts/vox-latest.dmg`
- `build/updates/appcast.xml`

The versioned GitHub Release stores:

- `appcast.xml`
- `Vox-{version}-{build}.dmg`
- `Vox-{version}-{build}.zip`
- `vox-latest.dmg`

The repository stores:

- `docs/appcast.xml`, served through `raw.githubusercontent.com`

## Homebrew Cask

The cask uses a comma-separated Homebrew version:

```ruby
version "0.1.2,02"
```

The first value is the marketing version and GitHub release tag suffix. The
second value is `CFBundleVersion` and the release ZIP suffix. For this version,
the cask URL resolves to:

```text
https://github.com/uicnz/vox/releases/download/v0.1.2/Vox-0.1.2-02.zip
```

After a release, calculate the SHA-256 from the versioned ZIP asset:

```bash
curl -L \
  https://github.com/uicnz/vox/releases/download/v0.1.2/Vox-0.1.2-02.zip \
  -o Vox.zip
shasum -a 256 Vox.zip
```

Update `aria-vox.rb` with the new version and SHA. Use `sha256 :no_check`
only until the first published ZIP exists.

Publish the cask in the Homebrew tap repository, not in the app release:

```bash
brew tap-new uicnz/vox
mkdir -p "$(brew --repository uicnz/vox)/Casks"
cp aria-vox.rb "$(brew --repository uicnz/vox)/Casks/aria-vox.rb"
```

Commit and push that tap repository. Users can then install Vox with:

```bash
brew install --cask uicnz/vox/aria-vox
```

## Critical Constraints

### CFBundleVersion Requirements

**Never reuse build numbers.** Sparkle requires update archives in
`build/updates/` to have unique, strictly increasing bundle versions. Before
publishing, the release tool validates that `package.json`, `Vox/Info.plist`,
`Vox.xcodeproj`, and `aria-vox.rb` agree, and that the source
`CFBundleVersion` is greater than the newest build in `docs/appcast.xml`.

- `build/updates/` should contain versioned DMGs only, plus `appcast.xml` and
  generated delta archives
- Do not place `vox-latest.dmg` in `build/updates/`; it duplicates the latest
  bundle version
- Duplicate build numbers block appcast generation and break updates for
  existing users
- Keep the last few versioned DMGs in `build/updates/` when you want Sparkle
  delta generation

If you accidentally create a release with a duplicate `CFBundleVersion`:

1. Delete the problematic DMG from `build/updates/`
2. Regenerate the feed:

   ```bash
   SPARKLE_URL="https://github.com/uicnz/vox/releases/download/v0.1.2/"
   .sourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast \
     --download-url-prefix "$SPARKLE_URL" \
     --maximum-deltas 3 \
     build/updates
   ```

3. Re-run `bun run release` or upload the corrected `appcast.xml`:

   ```bash
   cp build/updates/appcast.xml docs/appcast.xml
   git add docs/appcast.xml
   git commit -m "Update Sparkle appcast for 0.1.2"
   git push origin main
   gh release upload v0.1.2 build/updates/appcast.xml --clobber
   ```

## Troubleshooting

### Notarization Fails

- Check Apple ID credentials
- Verify the keychain profile exists: `aria-notarytool`
- Ensure `TEAM_ID` is correct when configuring the profile

### GitHub Upload Fails

- Run `gh auth status`
- Confirm the authenticated account can write to `uicnz/vox`
- Re-run with `--github-repo=owner/repo` for forks or test repositories

### Sparkle Updates Not Appearing

- Verify `appcast.xml` lists versions in descending `CFBundleVersion` order
- Check that `CFBundleVersion` values are unique and strictly increasing
- Ensure the feed URL is reachable:

  ```bash
  curl -I https://raw.githubusercontent.com/uicnz/vox/main/docs/appcast.xml
  ```

- Confirm release assets referenced by `appcast.xml` exist in the versioned
  GitHub Release

## Files

- `tools/src/build.ts` - Build, notarization, appcast generation, and GitHub
  publishing
- `Vox/Info.plist` - Sparkle feed URL and public EdDSA key
- `aria-vox.rb` - Homebrew cask formula
