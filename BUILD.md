# ScaleCloud Build Workflow

## Architecture

Four-layer iOS application built sequentially:

```
ScaleCloudGo (Go/Tailscale proxy)
    ↓
ScaleCloudKit (NextcloudKit fork)
    ↓
ScaleCloudApp (nextcloud/ios fork)
    ↓
ScaleCloudWrap (distribution wrapper)
```

## Build Process

Each layer:
1. Checks that lower-layer prebuilt dependencies exist in repository
2. Generates Xcode project with xcodegen
3. Builds with xcodebuild
4. Uploads artifact for manual download

You manually download artifacts, extract to `<layer>/prebuilt/`, and commit to repository.

## Step-by-Step

### 1. ScaleCloudGo
```bash
# In GitHub Actions UI: Run "Build ScaleCloudGo" workflow
# Downloads artifact: ScaleCloudGo-prebuilt.zip
unzip ScaleCloudGo-prebuilt.zip
# Contains: ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/
git add ScaleCloudGo/prebuilt/
git commit -m "Add Go prebuilt"
git push
```

**What it builds:** XCFramework from Go code using `gomobile bind`

### 2. ScaleCloudKit
```bash
# Requires: ScaleCloudGo/prebuilt/ committed
# In GitHub Actions UI: Run "Build ScaleCloudKit" workflow
# Downloads artifact: ScaleCloudKit-prebuilt.zip
unzip ScaleCloudKit-prebuilt.zip
# Contains: ScaleCloudKit/prebuilt/NextcloudKit.framework/
git add ScaleCloudKit/prebuilt/
git commit -m "Add Kit prebuilt"
git push
```

**What it builds:** Framework with module name "NextcloudKit" (for import compatibility)

### 3. ScaleCloudApp
```bash
# Requires: ScaleCloudKit/prebuilt/ committed
# In GitHub Actions UI: Run "Build ScaleCloudApp" workflow
# Downloads artifact: ScaleCloudApp-prebuilt.zip
unzip ScaleCloudApp-prebuilt.zip
# Contains: ScaleCloudApp/prebuilt/
git add ScaleCloudApp/prebuilt/  # Optional - large files
git commit -m "Add App prebuilt"
git push
```

**What it builds:** Main application archive

### 4. ScaleCloudWrap
```bash
# Requires: ScaleCloudApp/prebuilt/ committed
# In GitHub Actions UI: Run "Build ScaleCloudWrap" workflow
# Downloads artifact: ScaleCloudWrap-prebuilt.zip
```

**What it builds:** Final distribution package

## Workflow Details

### testbuildSCGo.yml (34 lines)
- Installs Go 1.26.3 and gomobile
- Runs: `gomobile bind -target=ios -o prebuilt/ScaleCloudGo.xcframework .`
- Output: XCFramework with Tailscale proxy

### testbuildSCKit.yml (51 lines)
- Checks Go prebuilt exists at `ScaleCloudGo/prebuilt/`
- Uses `sed` to remove Go target dependency from project.yml
- Uses `ruby` one-liner to inject framework search path
- Generates with xcodegen, builds with xcodebuild
- Extracts NextcloudKit.framework from archive

### testbuildSCApp.yml (41 lines)
- Checks Kit prebuilt exists at `ScaleCloudKit/prebuilt/`
- Downloads mock Firebase GoogleService-Info.plist
- Generates with xcodegen, builds with xcodebuild
- Archives full app

### testbuildSCWrap.yml (38 lines)
- Checks App prebuilt exists at `ScaleCloudApp/prebuilt/`
- Generates with xcodegen, builds with xcodebuild
- Creates final wrapper

## Rebuild Strategy

| Changed Layer | Rebuild Required |
|--------------|------------------|
| Go code | Go → Kit → App → Wrap |
| Kit code | Kit → App → Wrap |
| App code | App → Wrap |
| Wrap code | Wrap only |

## Upstream Compatibility

### Merging NextcloudKit changes
```bash
cd ScaleCloudKit
git remote add upstream https://github.com/nextcloud/NextcloudKit.git
git pull upstream main
# Resolve conflicts in Sources/
# project.yml won't conflict (separate from upstream)
```

### Merging nextcloud/ios changes
```bash
cd ScaleCloudApp
git remote add upstream https://github.com/nextcloud/ios.git
git pull upstream master
# Resolve conflicts in iOSClient/ and Brand/
# project.yml won't conflict (separate from upstream)
```

## Troubleshooting

**"prebuilt missing" error**
- Download the artifact from the lower-layer workflow run
- Extract to repository at `<layer>/prebuilt/`
- Commit and push before building next layer

**"module not found" error**
- Framework from lower layer is missing or in wrong location
- Verify path: `ls -la ScaleCloud*/prebuilt/`

**Build fails on xcodegen**
- Check that project.yml exists in layer directory
- Verify xcodegen is installed (workflow installs via brew)

**Firebase plist error (App only)**
- Workflow auto-downloads mock GoogleService-Info.plist
- If error persists, provide real plist in repository

## Key Design Decisions

**Manual artifacts** - Explicit control over when layers rebuild, no complex automation

**Uniform patterns** - All four workflows follow identical structure for maintainability

**Upstream compatibility** - Kit builds as "NextcloudKit" module name, minimal divergence from forks

**Maximum simplicity** - Shell commands only (sed, ruby), no Python scripts or complex logic
