# ScaleCloudKit Prebuilt

This directory holds the built NextcloudKit-compatible framework (a fork of upstream NextcloudKit with ScaleCloud proxy customizations).

## Expected layout after artifact download / materialize step (the only supported path)

```
ScaleCloudKit/prebuilt/
└── NextcloudKit.framework/     (module name is deliberately NextcloudKit for import compatibility)
    └── ...
```
(The directory name and module name are intentional so that the many `import NextcloudKit` statements coming from the transplanted upstream client sources continue to compile without mass edits.)

(The framework directory is named NextcloudKit.framework and the Swift module is NextcloudKit so that the large body of `import NextcloudKit` statements in the transplanted iOSClient/ and Brand/ sources continue to compile without mass renames. This is the key to maximising compatibility with upstream nextcloud/NextcloudKit and nextcloud/ios.)

## CI usage — independent layer build

- Use workflow: **Build ScaleCloudKit** (testbuildSCKit.yml)
- Before you dispatch it you must have manually obtained a Go prebuilt:
  - Download the `ScaleCloudGo-prebuilt` artifact from a prior successful "Build ScaleCloudGo" run.
  - Unpack it by hand into your clone so that `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework` (or .framework) exists.
- The Kit workflow itself will refuse to start (clear error in the first step) if that prebuilt tree is missing.
- Always produces:
  - `ScaleCloudKit-xcarchive`
  - `ScaleCloudKit-prebuilt` (contains `NextcloudKit.framework`)
- To build App/Wrap without rebuilding Kit: download the `ScaleCloudKit-prebuilt` artifact yourself and unpack it into `ScaleCloudKit/prebuilt/` before you dispatch App or Wrap.

The Kit layer's xcodegen project.yml pins exactly the same ALamofire/SwiftyJSON/SwiftyXMLParser versions as upstream NextcloudKit's Package.swift.

**There is no supported local / manual build for this layer.**

The only place `ScaleCloudKit` is generated and archived is inside the official **Build ScaleCloudKit** GitHub Actions workflow (`testbuildSCKit.yml`).

Typical independent usage:
- You dispatch the Go workflow, wait for success, download its `ScaleCloudGo-prebuilt` artifact.
- You unpack that artifact into `ScaleCloudGo/prebuilt/` in your clone.
- You dispatch the Kit workflow (no inputs about prior runs).
- The Kit job sees the Go prebuilt you placed there, generates only the Kit project, builds only the Kit layer, and publishes `ScaleCloudKit-prebuilt`.
- You later download that artifact and unpack it into `ScaleCloudKit/prebuilt/` when you are ready for an App or Wrap dispatch.

## Used by

- ScaleCloudApp (via the adapted ScaleCloudApp/ScaleCloudApp.xcodeproj copied from upstream nextcloud/ios Nextcloud.xcodeproj + our narrow edits for source roots + prebuilt NextcloudKit fileRef + FRAMEWORK_SEARCH_PATHS)
- ScaleCloudWrap (transitively)

## When to rebuild

- Any change to ScaleCloudKit/Sources (the actual fork contents)
- Changing the three SPM pins
- After a breaking ScaleCloudGo interface change

Rebuilding this layer means you will normally also want a fresh App build (and Wrap if you ship it).
