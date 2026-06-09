# ScaleCloud iOS

iOS client for Nextcloud with integrated Tailscale networking layer.

## Project Structure

```
ScaleCloudGo/       # Go networking layer (Tailscale + goproxy)
ScaleCloudKit/      # Fork of NextcloudKit (API/networking)
ScaleCloudApp/      # Fork of nextcloud/ios (main application)
ScaleCloudWrap/     # Distribution wrapper
```

## Technology Stack

### ScaleCloudGo
- **Language:** Go 1.26.3
- **Key Dependencies:**
  - tailscale.com v1.98.3 (VPN/networking)
  - goproxy v1.8.3 (HTTP proxy)
  - wlynxg/anet v0.0.5 (Android network utilities)
- **Output:** XCFramework for iOS (via gomobile)

### ScaleCloudKit
- **Language:** Swift
- **Framework Name:** ScaleCloudKit.framework
- **Dependencies:**
  - Alamofire 5.10.2+ (HTTP networking)
  - SwiftyJSON 5.0.2+ (JSON parsing)
  - SwiftyXMLParser 5.6.0+ (XML parsing)
- **Upstream:** https://github.com/nextcloud/NextcloudKit
- **Note:** Built as ScaleCloudKit.framework (not NextcloudKit)

### ScaleCloudApp
- **Language:** Swift
- **Dependencies:**
  - ScaleCloudKit (framework from ScaleCloudKit layer)
  - ScaleCloudGo (XCFramework from Go layer)
  - RealmSwift (database)
  - MobileVLCKit (media playback)
  - LucidBanner (notifications)
  - Additional nextcloud/ios dependencies
- **Upstream:** https://github.com/nextcloud/ios
- **Note:** Uses committed .xcodeproj (not generated), with framework search paths pre-configured

### ScaleCloudWrap
- **Language:** Swift
- **Purpose:** Distribution packaging and configuration

## Build System

Uses GitHub Actions with xcodegen-based project generation. Each layer builds independently and produces artifacts that are manually committed to repository.

**See [BUILD.md](BUILD.md) for complete build instructions.**

Quick summary:
1. Build Go layer → download artifact → commit to `ScaleCloudGo/prebuilt/`
2. Build Kit layer → download artifact → commit to `ScaleCloudKit/prebuilt/`
3. Build App layer → download artifact → commit to `ScaleCloudApp/prebuilt/`
4. Build Wrap layer → download artifact (final deliverable)

### Recent Build History

**June 9, 2026** - ScaleCloud features integration and successful compilation
- Added 3 missing Swift files to Xcode project (ScaleCloudWatchedFolders*, ScaleCloudDownloadsHelper)
- Fixed iOS security-scoped bookmark API usage (removed macOS-only `.withSecurityScope` option)
- Fixed optional binding error in NCSession.getSession() call
- Updated framework references from NextcloudKit.framework to ScaleCloudKit.framework
- **Result:** ✅ All targets compile successfully
- **Commits:** `5f5eeef196`, `4134dffed0`, `2cdd5fd09b`, `68cf83aec6`

## Development Environment

- **Xcode:** 16.2
- **iOS Deployment Target:** 14.0+
- **macOS:** Required for building (uses macOS-14 runners in CI)

### Local Build Requirements
- Xcode 16.2+
- Go 1.26.3 (for ScaleCloudGo)
- gomobile (`go install golang.org/x/mobile/cmd/gomobile@latest`)
- xcodegen (`brew install xcodegen`)

## Architecture Principles

### Layered Dependencies
Each layer depends only on layers below it. No circular dependencies.

### Manual Artifact Management
Prebuilt frameworks are committed to repository rather than fetched dynamically. This provides:
- Explicit rebuild control
- Faster CI builds (rebuild only changed layers)
- Clear dependency tracking
- No complex automation

### Upstream Compatibility
- Kit maintains "NextcloudKit" module name for import compatibility
- Minimal divergence from upstream nextcloud/ios and NextcloudKit
- Can pull and merge upstream changes without breaking build system

### Project Generation
Uses xcodegen to generate .xcodeproj files from project.yml specifications:
- Version control friendly (YAML instead of XML pbxproj)
- Declarative configuration
- Easy to modify and maintain

## Repository Layout

```
.github/workflows/       # GitHub Actions workflows
  ├── testbuildSCGo.yml
  ├── testbuildSCKit.yml
  ├── testbuildSCApp.yml
  └── testbuildSCWrap.yml

ScaleCloudGo/
  ├── go.mod, go.sum      # Go module definition
  ├── *.go                # Go source code
  ├── project.yml         # xcodegen spec (not used in simplified workflow)
  └── prebuilt/           # Committed XCFramework

ScaleCloudKit/
  ├── Package.swift       # SPM definition (from upstream)
  ├── project.yml         # xcodegen spec
  ├── Sources/            # Swift source code
  └── prebuilt/           # Committed NextcloudKit.framework

ScaleCloudApp/
  ├── project.yml         # xcodegen spec
  ├── iOSClient/          # Application source
  ├── Brand/              # Branding assets
  └── prebuilt/           # Committed app archive

ScaleCloudWrap/
  ├── project.yml         # xcodegen spec
  └── prebuilt/           # Final distribution

tuistbackup/             # Old Tuist-based build system (archived)
BUILD.md                 # Build workflow documentation
README.md               # This file
```

## Contributing

### Making Changes

1. **Modify Go layer:** Edit .go files in ScaleCloudGo/, rebuild Go → Kit → App → Wrap
2. **Modify Kit layer:** Edit Swift files in ScaleCloudKit/Sources/, rebuild Kit → App → Wrap
3. **Modify App layer:** Edit files in ScaleCloudApp/iOSClient/, rebuild App → Wrap
4. **Modify Wrap layer:** Edit ScaleCloudWrap/ files, rebuild Wrap only

### Pulling Upstream Changes

See BUILD.md "Upstream Compatibility" section for merge instructions.

## Features

### Core Nextcloud Features
- **Tailscale Integration:** Native Go-based Tailscale client in iOS app
- **Nextcloud Client:** Full-featured Nextcloud iOS client functionality
- **Offline Support:** Local file caching and sync
- **Media Playback:** Integrated video/audio player
- **Secure Networking:** VPN-layer security via Tailscale

### ScaleCloud-Specific Features
- **Custom Login UI:** Specialized login flow for Tailscale-hosted Nextcloud instances
- **Watched Download Folders:** Monitor user-selected folders and automatically upload new files
- **Auto-Upload Integration:** Enhanced auto-upload for photos, videos, and watched folders
- **Security-Scoped Bookmarks:** Persistent access to user-selected folders across app restarts

## License

Inherits licenses from upstream components:
- Nextcloud iOS client: GPLv3
- NextcloudKit: GPLv3
- Tailscale: BSD 3-Clause
- Individual dependencies: See respective licenses

## Links

- **Upstream NextcloudKit:** https://github.com/nextcloud/NextcloudKit
- **Upstream Nextcloud iOS:** https://github.com/nextcloud/ios
- **Tailscale:** https://tailscale.com
