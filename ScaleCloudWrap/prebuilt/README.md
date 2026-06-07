# ScaleCloudWrap Prebuilt Archive

This directory contains the precompiled ScaleCloudWrap.xcarchive.

## Contents

```
ScaleCloudWrap.xcarchive/
├── Info.plist
├── Products/
└── dSYMs/
```

## How to Build

**Prerequisites**: All lower layers must have prebuilt artifacts:
- `ScaleCloudGo/prebuilt/`
- `ScaleCloudKit/prebuilt/`
- `ScaleCloudApp/prebuilt/`

Run the GitHub Actions workflow:
- Workflow: `testbuild.yml`
- Layer: `wrap`

Or build locally:
```bash
tuist generate ScaleCloudWrap
cd ScaleCloudWrap
xcodebuild archive \
  -scheme ScaleCloudWrap \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/prebuilt/ScaleCloudWrap.xcarchive"
```

## Dependencies

- Requires: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework`
- Requires: `ScaleCloudKit/prebuilt/ScaleCloudKit.xcarchive`
- Requires: `ScaleCloudApp/prebuilt/ScaleCloudApp.xcarchive`

## Used By

This is the top layer - nothing depends on it.

## When to Rebuild

Rebuild when you modify:
- Any source files in `ScaleCloudWrap/`
- Or when any lower layer is rebuilt
