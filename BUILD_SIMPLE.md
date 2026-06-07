# Simple Build System

## How It Works

Each layer builds independently. You manually download artifacts and put them in `/prebuilt/` folders.

## Build Order

```
ScaleCloudGo → ScaleCloudKit → ScaleCloudApp → ScaleCloudWrap
```

## Step by Step

### 1. Build ScaleCloudGo

1. Go to Actions → "Build ScaleCloudGo" → Run workflow
2. Wait for it to finish
3. Download the `ScaleCloudGo-prebuilt` artifact
4. Extract it so you have: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/`
5. Commit and push:
   ```bash
   git add ScaleCloudGo/prebuilt/
   git commit -m "Add Go prebuilt"
   git push
   ```

### 2. Build ScaleCloudKit

1. Make sure `ScaleCloudGo/prebuilt/` exists (from step 1)
2. Go to Actions → "Build ScaleCloudKit" → Run workflow
3. Download the `ScaleCloudKit-prebuilt` artifact
4. Extract it so you have: `ScaleCloudKit/prebuilt/NextcloudKit.framework/`
5. Commit and push:
   ```bash
   git add ScaleCloudKit/prebuilt/
   git commit -m "Add Kit prebuilt"
   git push
   ```

### 3. Build ScaleCloudApp

1. Make sure `ScaleCloudKit/prebuilt/` exists (from step 2)
2. Go to Actions → "Build ScaleCloudApp" → Run workflow
3. Download the `ScaleCloudApp-prebuilt` artifact
4. Extract it to `ScaleCloudApp/prebuilt/`
5. Commit and push (optional, it's large)

### 4. Build ScaleCloudWrap

1. Make sure `ScaleCloudApp/prebuilt/` exists (from step 3)
2. Go to Actions → "Build ScaleCloudWrap" → Run workflow
3. Download the `ScaleCloudWrap-prebuilt` artifact
4. This is your final deliverable

## What Changed

### Old Workflows (DELETED)
- 200+ lines each
- Python scripts to manipulate pbxproj files
- Complex conditional logic
- Hard to understand

### New Workflows (NOW)
- ~30 lines each
- Plain shell commands
- Simple: check prebuilt exists → generate project → build → upload
- Easy to read and modify

## Each Workflow Does

### ScaleCloudGo (`testbuildSCGo.yml`)
```yaml
- Install Go + gomobile
- Run: gomobile bind -target=ios -o ScaleCloudGo.xcframework
- Upload: ScaleCloudGo/prebuilt/
```

### ScaleCloudKit (`testbuildSCKit.yml`)
```yaml
- Check Go prebuilt exists
- Generate project with xcodegen (removes Go dependency, adds framework search path)
- Build with xcodebuild
- Upload: ScaleCloudKit/prebuilt/
```

### ScaleCloudApp (`testbuildSCApp.yml`)
```yaml
- Check Kit prebuilt exists
- Generate project with xcodegen
- Build with xcodebuild
- Upload: ScaleCloudApp/prebuilt/
```

### ScaleCloudWrap (`testbuildSCWrap.yml`)
```yaml
- Check App prebuilt exists
- Generate project with xcodegen
- Build with xcodebuild
- Upload: ScaleCloudWrap/prebuilt/
```

## Upstream Compatibility

### Pulling from upstream NextcloudKit
```bash
cd ScaleCloudKit
git remote add upstream https://github.com/nextcloud/NextcloudKit.git
git pull upstream main
# Resolve any conflicts in Sources/
# Your project.yml is separate and won't conflict
```

### Pulling from upstream nextcloud/ios
```bash
cd ScaleCloudApp
git remote add upstream https://github.com/nextcloud/ios.git
git pull upstream master
# Resolve conflicts in iOSClient/ and Brand/
# Your project.yml is separate
```

## Why Manual Artifacts?

1. **Simple**: No complex cross-workflow artifact fetching
2. **Explicit**: You control when layers are rebuilt
3. **Fast**: Rebuild only what changed
4. **Cheap**: Don't pay for unused CI minutes

## When to Rebuild

- **Changed Go code?** → Rebuild Go, Kit, App, Wrap
- **Changed Kit code?** → Rebuild Kit, App, Wrap
- **Changed App code?** → Rebuild App, Wrap
- **Changed Wrap code?** → Rebuild Wrap only

## Troubleshooting

### "Go prebuilt missing"
Download `ScaleCloudGo-prebuilt` from a Go workflow run and extract to repo root.

### "Kit prebuilt missing"  
Download `ScaleCloudKit-prebuilt` from a Kit workflow run and extract to repo root.

### "App prebuilt missing"
Download `ScaleCloudApp-prebuilt` from an App workflow run and extract to repo root.

### Build fails with "module not found"
The prebuilt from the layer below is missing or in the wrong location.

## That's It

No complex scripts. No magic. Just:
1. Build layer
2. Download artifact  
3. Extract to `/prebuilt/`
4. Build next layer

Simple.
