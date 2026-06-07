# ScaleCloud Build Workflow

## Overview

To save GitHub Actions credits, we build each layer **independently** with smart prebuilt dependency detection. Each layer stores its prebuilt artifacts in its own `prebuilt/` subdirectory.

**Key Innovation**: Each `Project.swift` contains a post-build script that checks if a prebuilt version exists. If it does, the script uses the prebuilt version instead of building from source. This allows us to use `.project()` references everywhere while still benefiting from prebuilt artifacts.

## Directory Structure

```
scalecloud-ios/
├── ScaleCloudGo/
│   ├── Project.swift                     # Post-build script: uses prebuilt if exists
│   └── prebuilt/
│       └── ScaleCloudGo.xcframework/     # Built with gomobile bind
├── ScaleCloudKit/
│   ├── Project.swift                     # Post-build script: uses prebuilt if exists
│   └── prebuilt/
│       └── ScaleCloudKit.framework/      # Built with xcodebuild
├── ScaleCloudApp/
│   ├── Project.swift                     # Post-build script: uses prebuilt if exists
│   └── prebuilt/
│       └── ScaleCloudApp.app/            # Built with xcodebuild
└── ScaleCloudWrap/
    ├── Project.swift                     # Post-build script: uses prebuilt if exists
    └── prebuilt/
        └── ScaleCloudWrap.*/              # Built with xcodebuild
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

## How It Works

### The Magic: Conditional Prebuilt Scripts

Each `Project.swift` contains a post-build script:

```swift
scripts: [
    .post(
        script: """
PREBUILT_FRAMEWORK="$PROJECT_DIR/prebuilt/ScaleCloudKit.framework"
TARGET_FRAMEWORK="$BUILT_PRODUCTS_DIR/ScaleCloudKit.framework"

if [ -d "$PREBUILT_FRAMEWORK" ]; then
    echo "Using prebuilt ScaleCloudKit.framework"
    rm -rf "$TARGET_FRAMEWORK"
    cp -R "$PREBUILT_FRAMEWORK" "$TARGET_FRAMEWORK"
else
    echo "Using freshly built ScaleCloudKit.framework"
fi
""",
        name: "Use Prebuilt Framework If Available"
    )
]
```

This means:
- **If `prebuilt/` exists**: Copy it instead of using the just-built version
- **If `prebuilt/` missing**: Use the freshly compiled version

### Project References

All projects use `.project()` references (not `.framework()` or `.xcframework()`):
- ScaleCloudKit depends on `.project(target: "ScaleCloudGo", path: "../ScaleCloudGo")`
- ScaleCloudApp depends on `.project(target: "ScaleCloudKit", path: "../ScaleCloudKit")`

This allows Tuist to generate the full workspace without errors, even when prebuilt frameworks don't exist yet.

### Build Process

1. **Generate entire workspace**: `tuist install` + `tuist generate`
2. **Build specific scheme**: `xcodebuild -workspace ScaleCloud.xcworkspace -scheme ScaleCloudKit`
3. **Dependencies automatically resolved**:
   - If ScaleCloudGo/prebuilt exists → post-build script uses it (no Go tools needed!)
   - If ScaleCloudGo/prebuilt missing → builds from source
4. **Copy output to prebuilt**: `cp -R .build/Build/Products/Release-iphoneos/ScaleCloudKit.framework ScaleCloudKit/prebuilt/`

## Build Order (IMPORTANT!)

You **must** build from bottom to top:

### 1. Build ScaleCloudGo (First - No dependencies)

**Via GitHub Actions**:
1. Go to **Actions** tab
2. Select **"Build Selected Layer (Standalone)"**
3. Click **"Run workflow"**
4. Select layer: **`go`**
5. Click **"Run workflow"**

**What it builds**: Go framework with Tailscale proxy using `gomobile bind -target=ios`

**Output**: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/`

**Requirements**: Go 1.26, gomobile (automatically installed by workflow)

**How to commit**:
1. Download `go-build` artifact from GitHub Actions (Actions tab → workflow run → Artifacts)
2. Extract the ZIP to your repo root (it will place files in correct locations)
3. Commit and push:
```bash
git add ScaleCloudGo/prebuilt/
git commit -m "Add prebuilt ScaleCloudGo.xcframework from CI build"
git push
```

### 2. Build ScaleCloudKit (Second - Requires Go)

**Prerequisites**: ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions**:
1. Go to **Actions** tab
2. Select **"Build Selected Layer (Standalone)"**
3. Click **"Run workflow"**
4. Select layer: **`kit`**
5. Click **"Run workflow"**

**What it builds**: NextcloudKit fork that uses prebuilt ScaleCloudGo (no Go tools needed!)

**Output**: `ScaleCloudKit/prebuilt/ScaleCloudKit.framework/`

**Key**: ScaleCloudGo's post-build script detects `prebuilt/ScaleCloudGo.xcframework` and uses it automatically

**How to commit**:
1. Download `kit-build` artifact from GitHub Actions
2. Extract to repo root
3. Commit and push:
```bash
git add ScaleCloudKit/prebuilt/
git commit -m "Add prebuilt ScaleCloudKit.framework from CI build"
git push
```

### 3. Build ScaleCloudApp (Third - Requires Go + Kit)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudKit/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions**:
1. Go to **Actions** tab
2. Select **"Build Selected Layer (Standalone)"**
3. Click **"Run workflow"**
4. Select layer: **`app`**
5. Click **"Run workflow"**

**What it builds**: Main iOS app using prebuilt Go and Kit frameworks

**Output**: `ScaleCloudApp/prebuilt/ScaleCloudApp.app/`

**Key**: Both ScaleCloudGo and ScaleCloudKit post-build scripts detect prebuilt versions and use them

**How to commit**:
1. Download `app-build` artifact from GitHub Actions
2. Extract to repo root
3. Commit and push:
```bash
git add ScaleCloudApp/prebuilt/
git commit -m "Add prebuilt ScaleCloudApp.app from CI build"
git push
```

### 4. Build ScaleCloudWrap (Last - Requires All)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudKit/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudApp/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions**:
1. Go to **Actions** tab
2. Select **"Build Selected Layer (Standalone)"**
3. Click **"Run workflow"**
4. Select layer: **`wrap`**
5. Click **"Run workflow"**

**What it builds**: Top-level wrapper using all prebuilt layers

**Output**: `ScaleCloudWrap/prebuilt/ScaleCloudWrap.*/`

**Note**: ScaleCloudWrap is not yet implemented

**How to commit**:
1. Download `wrap-build` artifact from GitHub Actions
2. Extract to repo root
3. Commit and push:
```bash
git add ScaleCloudWrap/prebuilt/
git commit -m "Add prebuilt ScaleCloudWrap from CI build"
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

### Old Workflow ("0 allbuild testbuild.yml")
Every build rebuilt the entire chain from source:
- Build any layer → always rebuilds Go (requires Go 1.26, gomobile) → rebuilds Kit → rebuilds App
- **Cost**: ~15-25 minutes per run
- **Always installs**: Go tools (even when not modifying Go code)

### New Workflow (Current)
Only rebuilds the selected layer, uses prebuilt dependencies:
- Build Kit with prebuilt Go → **no Go tools needed**, ~3-5 minutes
- Build App with prebuilt Go+Kit → **no Go tools needed**, ~4-6 minutes  
- Build Go from source → ~6-8 minutes
- **Cost**: Varies by layer, typically ~5 minutes

**Savings**: 
- **~60-70% reduction** in build time for non-Go changes
- **~80% reduction** in Go toolchain installation time
- **Massive credit savings** on typical development (UI/logic changes don't rebuild Go)

## Local Development

You can build locally with Tuist:

```bash
# Install external dependencies (Alamofire, etc.)
tuist install

# Generate entire workspace
tuist generate

# Open in Xcode
open ScaleCloud.xcworkspace
```

**Local builds automatically use prebuilt dependencies**:
- If `ScaleCloudGo/prebuilt/` exists → uses it (no Go needed!)
- If `ScaleCloudKit/prebuilt/` exists → uses it
- If missing → builds from source

**To force a clean rebuild** of a layer:
```bash
rm -rf ScaleCloudKit/prebuilt/
tuist generate
# Now Kit will build from source
```

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

### Build Fails: Module Not Found (e.g., "no such module 'Alamofire'")

External dependencies aren't resolved. This happens if you skip `tuist install`.

**Solution**:
```bash
tuist install
tuist generate
```

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
   - Kit: `ScaleCloudKit/prebuilt/ScaleCloudKit.framework/`
   - App: `ScaleCloudApp/prebuilt/ScaleCloudApp.app/`

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

A: Yes, but then those layers will rebuild from source on every build. The whole point of this system is to keep prebuilt artifacts committed so they can be reused. Use Git LFS if size is an issue.

**Q: What's in the GitHub Actions artifacts?**

A: The ZIP contains the `[Layer]/prebuilt/` directory with the built framework/app. Download and extract it to the repo root - it will place files in the correct locations.

**Q: Why use `.project()` references if we have prebuilt frameworks?**

A: So Tuist can generate the workspace without errors. The post-build scripts handle the conditional logic of using prebuilt vs source. This is simpler than trying to conditionally modify `Project.swift` files.

**Q: Do I need Go installed locally?**

A: Only if you're modifying Go code AND don't have `ScaleCloudGo/prebuilt/`. If the prebuilt exists, the post-build script uses it and Go isn't needed.
