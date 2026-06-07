# ScaleCloud Build Workflow

## Overview

To save GitHub Actions credits, we now build each layer **independently** instead of building the entire dependency chain. Each layer stores its prebuilt artifacts in its own `prebuilt/` subdirectory.

## Directory Structure

```
scalecloud-ios/
├── ScaleCloudGo/
│   └── prebuilt/
│       └── ScaleCloudGo.xcframework/    # Built with gomobile
├── ScaleCloudKit/
│   └── prebuilt/
│       └── ScaleCloudKit.xcarchive/     # Built with xcodebuild
├── ScaleCloudApp/
│   └── prebuilt/
│       └── ScaleCloudApp.xcarchive/     # Built with xcodebuild
└── ScaleCloudWrap/
    └── prebuilt/
        └── ScaleCloudWrap.xcarchive/    # Built with xcodebuild
```

## Dependency Chain

```
ScaleCloudGo (底层 - Bottom layer)
    ↓ used by
ScaleCloudKit
    ↓ used by
ScaleCloudApp
    ↓ used by
ScaleCloudWrap (顶层 - Top layer)
```

## Build Order (IMPORTANT!)

You **must** build from bottom to top:

### 1. Build ScaleCloudGo (First - No dependencies)

```bash
# Via GitHub Actions:
# Go to Actions → "Build Selected Layer (Standalone)" → Run workflow → Select "go"
```

**What it builds**: Go framework with Tailscale proxy using `gomobile bind`

**Output**: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/`

**How to commit**:
```bash
# Download artifact from GitHub Actions
# Extract to repo root
git add ScaleCloudGo/prebuilt/
git commit -m "Update prebuilt ScaleCloudGo"
git push
```

### 2. Build ScaleCloudKit (Second - Requires Go)

**Prerequisites**: ✅ `ScaleCloudGo/prebuilt/` must exist

```bash
# Via GitHub Actions:
# Go to Actions → "Build Selected Layer (Standalone)" → Run workflow → Select "kit"
```

**What it builds**: NextcloudKit fork that links against prebuilt Go framework

**Output**: `ScaleCloudKit/prebuilt/ScaleCloudKit.xcarchive/`

**How to commit**:
```bash
# Download artifact from GitHub Actions
# Extract to repo root
git add ScaleCloudKit/prebuilt/
git commit -m "Update prebuilt ScaleCloudKit"
git push
```

### 3. Build ScaleCloudApp (Third - Requires Go + Kit)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist
- ✅ `ScaleCloudKit/prebuilt/` must exist

```bash
# Via GitHub Actions:
# Go to Actions → "Build Selected Layer (Standalone)" → Run workflow → Select "app"
```

**What it builds**: Main iOS app linking against prebuilt Go and Kit

**Output**: `ScaleCloudApp/prebuilt/ScaleCloudApp.xcarchive/`

**How to commit**:
```bash
# Download artifact from GitHub Actions
# Extract to repo root
git add ScaleCloudApp/prebuilt/
git commit -m "Update prebuilt ScaleCloudApp"
git push
```

### 4. Build ScaleCloudWrap (Last - Requires All)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist
- ✅ `ScaleCloudKit/prebuilt/` must exist
- ✅ `ScaleCloudApp/prebuilt/` must exist

```bash
# Via GitHub Actions:
# Go to Actions → "Build Selected Layer (Standalone)" → Run workflow → Select "wrap"
```

**What it builds**: Top-level wrapper linking all layers

**Output**: `ScaleCloudWrap/prebuilt/ScaleCloudWrap.xcarchive/`

**How to commit**:
```bash
# Download artifact from GitHub Actions
# Extract to repo root
git add ScaleCloudWrap/prebuilt/
git commit -m "Update prebuilt ScaleCloudWrap"
git push
```

## When You Make Changes

The key rule: **rebuild the modified layer AND all layers above it**.

### Example 1: Modified `ScaleCloudGo.go`

You changed the Go bridge code:

1. ✅ Build `go` → commit
2. ✅ Build `kit` → commit
3. ✅ Build `app` → commit
4. ✅ Build `wrap` → commit

**All 4 layers** must be rebuilt.

### Example 2: Modified `ScaleCloudKit/Sources/ScaleCloudKit/SCKSession.swift`

You changed the Kit networking layer:

1. ❌ Skip `go` (unchanged)
2. ✅ Build `kit` → commit
3. ✅ Build `app` → commit
4. ✅ Build `wrap` → commit

**3 layers** need rebuilding.

### Example 3: Modified `ScaleCloudApp/iOSClient/Login/NCLogin.swift`

You changed the iOS app UI:

1. ❌ Skip `go` (unchanged)
2. ❌ Skip `kit` (unchanged)
3. ✅ Build `app` → commit
4. ✅ Build `wrap` → commit

**2 layers** need rebuilding.

### Example 4: Modified `ScaleCloudWrap/` only

1. ❌ Skip `go` (unchanged)
2. ❌ Skip `kit` (unchanged)
3. ❌ Skip `app` (unchanged)
4. ✅ Build `wrap` → commit

**1 layer** needs rebuilding.

## Cost Savings

### Old Workflow
Every build rebuilt the entire chain:
- Build Wrap → builds App → builds Kit → builds Go
- **Cost**: ~20-30 minutes per run

### New Workflow
Only build what changed:
- Typical UI change: only rebuild App + Wrap
- **Cost**: ~5-10 minutes per run

**Savings**: ~66% reduction in build time and GitHub Actions credits!

## Local Development

You can still build locally with Tuist:

```bash
# Build everything (full chain)
tuist generate

# Build specific project
tuist generate ScaleCloudKit
```

Local builds will use prebuilt dependencies from the `prebuilt/` folders.

## Git LFS (Recommended for Large Repos)

The prebuilt binaries can be large. Consider Git LFS:

```bash
git lfs install
git lfs track "*/prebuilt/**"
git add .gitattributes
git commit -m "Track prebuilt binaries with Git LFS"
```

## Troubleshooting

### Error: "prebuilt dependencies not found"

You tried to build a layer without its dependencies. Build lower layers first.

**Example**: Building `app` without `kit`:
```
ERROR: ScaleCloudKit/prebuilt not found!
Please build and commit ScaleCloudKit first.
```

**Solution**: Build `kit` first, commit, then build `app`.

### Build Fails: Framework Not Found

The build system can't find a prebuilt framework. Check:

1. Does the `prebuilt/` directory exist?
   ```bash
   ls -la ScaleCloudGo/prebuilt/
   ls -la ScaleCloudKit/prebuilt/
   ```

2. Did you pull the latest commits?
   ```bash
   git pull
   git lfs pull  # If using LFS
   ```

3. Is the framework structure correct?
   - Go: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/`
   - Kit: `ScaleCloudKit/prebuilt/ScaleCloudKit.xcarchive/`

### Workflow Fails Immediately

Check the "Verify prebuilt dependencies" step in the Actions log. It tells you exactly which dependencies are missing.

## FAQ

**Q: Can I build multiple layers in one workflow run?**

A: No. Each layer must be built separately, committed, then the next layer can be built.

**Q: What if I want to do a clean rebuild of everything?**

A: Build all 4 layers in order: `go` → `kit` → `app` → `wrap`, committing after each.

**Q: Do I need to commit after every build?**

A: Yes! Higher layers depend on lower layers being in the repo. The workflow checks for their existence.

**Q: Can I delete the `prebuilt/` folders to save space?**

A: No! The build process requires them. They should be committed to the repo. Use Git LFS if size is an issue.

**Q: What's in the GitHub Actions artifacts?**

A: The same content that should go in the `prebuilt/` folder. Download and extract it to the repo root - it will place files in the correct locations.
