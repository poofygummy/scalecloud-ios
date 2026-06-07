# ScaleCloudKit Prebuilt Archive

This directory contains the precompiled ScaleCloudKit.xcarchive.

## Contents

```
ScaleCloudKit.xcarchive/
├── Info.plist
├── Products/
│   └── Library/
│       └── Frameworks/
│           └── ScaleCloudKit.framework/
└── dSYMs/
```

## How to Build

**Prerequisites**: `ScaleCloudGo/prebuilt/` must exist first!

Run the GitHub Actions workflow:
- Workflow: `testbuild.yml`
- Layer: `kit`

Or build locally:
```bash
tuist generate ScaleCloudKit
cd ScaleCloudKit
xcodebuild archive \
  -scheme ScaleCloudKit \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/prebuilt/ScaleCloudKit.xcarchive"
```

## Dependencies

- Requires: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework`

## Used By

- ScaleCloudApp (depends on this framework)
- ScaleCloudWrap (transitively)

## When to Rebuild

Rebuild when you modify:
- Any Swift source files in `ScaleCloudKit/Sources/`
- `ScaleCloudKit/Project.swift`
- Or when ScaleCloudGo is rebuilt

After rebuilding, **you must also rebuild**:
- ScaleCloudApp
- ScaleCloudWrap
