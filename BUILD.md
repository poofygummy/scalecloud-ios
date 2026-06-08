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
2. For Go/Kit/Wrap: Generates Xcode project with xcodegen from project.yml
3. For App: Uses existing committed ScaleCloudApp.xcodeproj (from upstream nextcloud/ios)
4. Injects framework search paths to prebuilt dependencies
5. Builds with xcodebuild or gomobile
6. Uploads artifact for manual download

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

### testbuildSCKit.yml
- **Project generation:** Uses xcodegen with modified project.yml (strips ScaleCloudGo dependency)
- Checks Go prebuilt exists at `ScaleCloudGo/prebuilt/`
- Uses `sed` to remove Go target dependency from project.yml
- Generates project with xcodegen
- Uses `ruby` to inject framework search path for Go prebuilt
- Builds framework with `xcodebuild build` (not archive - frameworks don't archive)
- Extracts ScaleCloudKit.framework from build products directory

### testbuildSCApp.yml
- **Project generation:** NONE - uses existing committed ScaleCloudApp.xcodeproj from upstream nextcloud/ios
- Checks Kit and Go prebuilts exist at `ScaleCloudKit/prebuilt/` and `ScaleCloudGo/prebuilt/`
- Downloads mock Firebase GoogleService-Info.plist
- Uses `ruby` to inject framework search path for Kit prebuilt into existing xcodeproj
- Builds app with `xcodebuild archive`
- Copies archive to prebuilt directory

### testbuildSCWrap.yml
- **Project generation:** Uses xcodegen with modified project.yml (strips ScaleCloudApp dependency)
- Checks App prebuilt exists at `ScaleCloudApp/prebuilt/`
- Uses `sed` to remove App target dependency from project.yml
- Generates project with xcodegen
- Uses `ruby` to inject framework search path for App prebuilt
- Builds with `xcodebuild archive`
- Creates final distribution wrapper

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
# Resolve conflicts in iOSClient/, Brand/, and ScaleCloudApp.xcodeproj/
# The committed ScaleCloudApp.xcodeproj is maintained and updateable from upstream
# Workflow modifies it at build time to inject prebuilt framework paths
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

**Upstream compatibility** - Kit builds as "ScaleCloudKit" module. App layer uses committed upstream xcodeproj (updateable via git merge), modified at build time for prebuilt linking

**Maximum simplicity** - Shell commands only (sed, ruby), no Python scripts or complex logic
