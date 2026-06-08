# GitHub Actions Workflows for Vox

This directory contains the CI/CD workflows for the Vox project.

## Workflows

### 1. CI (`ci.yml`)

- **Trigger**: On every push to main and pull requests
- **Purpose**: Continuous integration for code quality
- **Jobs**:
  - Swift linting with SwiftLint
  - Build and test in both Debug and Release configurations
  - Caches Swift Package Manager dependencies

### 2. Build and Release (`build-and-release.yml`)

- **Trigger**: On push to main and on version tags (v*)
- **Purpose**: Build, test, and create releases
- **Jobs**:
  - Build and test the app
  - Create release artifacts when a tag is pushed
  - Generate DMG installer
  - Create GitHub releases with changelog and Sparkle assets

### 3. Manual Release (`release.yml`)

- **Trigger**: Manual workflow dispatch
- **Purpose**: Create signed and notarized releases
- **Inputs**:
  - Version number (e.g., 0.2.4)
  - Build number (e.g., 37)
- **Features**:
  - Code signing and notarization
  - DMG creation
  - Sparkle appcast generation
  - GitHub Release asset upload

## Required Secrets

For the release workflows to work properly, you need to configure these secrets in your GitHub repository:

### For Code Signing (release.yml)

- `MACOS_CERTIFICATE`: Base64 encoded .p12 certificate
- `MACOS_CERTIFICATE_PWD`: Password for the certificate
- `KEYCHAIN_PWD`: Password for the temporary keychain
- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID (N68C9LUA5B)

### For Notarization (release.yml)

- `APPLE_ID`: Your Apple ID email
- `APPLE_ID_PASSWORD`: App-specific password for notarization
- `TEAM_ID`: Your Apple Team ID

### For Sparkle Updates

- `SPARKLE_PRIVATE_KEY`: For signing Sparkle updates when CI cannot access the local Sparkle keychain item

## Usage

### Creating a Release

1. **Using Tags** (Recommended for releases):

   ```bash
   git tag v0.2.4
   git push origin v0.2.4
   ```

   This will trigger the build-and-release workflow.

2. **Manual Release** (For signed/notarized releases):
   - Go to Actions → Release → Run workflow
   - Enter version and build numbers
   - The workflow will handle signing, notarization, and release creation

### Setting Up Secrets

1. Go to Settings → Secrets and variables → Actions
2. Add each required secret

To create the certificate secret:

```bash
# Export your Developer ID certificate from Keychain Access as .p12
# Then convert to base64:
base64 -i certificate.p12 | pbcopy
```

### Sparkle Integration

Sparkle assets are hosted in the dedicated GitHub Release tagged `sparkle`:

```text
https://github.com/uicnz/vox/releases/download/sparkle/appcast.xml
```

The release script creates or updates that release, uploads `appcast.xml`, uploads `vox-latest.dmg`, and uploads the versioned DMGs/deltas referenced by the feed.

## Notes

- The CI workflow runs on every push and PR for quick feedback
- Release builds are only created for version tags or manual triggers
- All builds target macOS 15+ and Apple Silicon
- SwiftLint is configured but set to continue on error to avoid blocking PRs
