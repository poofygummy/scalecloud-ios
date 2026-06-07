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
- Optional input: `go_run_id` — if you pass the run ID of a prior successful "Build ScaleCloudGo" that published `ScaleCloudGo-prebuilt`, the Kit workflow will fetch that artifact and unpack it under `ScaleCloudGo/prebuilt/` before anything else runs. This removes the entire Go+gomobile toolchain installation and execution from the Kit GitHub job.
- Always produces:
  - `ScaleCloudKit-xcarchive`
  - `ScaleCloudKit-prebuilt` (contains `NextcloudKit.framework`)
- To build App/Wrap without rebuilding Kit: supply the prior `kit_run_id` to the App or Wrap `workflow_dispatch`.

The Kit layer's xcodegen project.yml pins exactly the same ALamofire/SwiftyJSON/SwiftyXMLParser versions as upstream NextcloudKit's Package.swift.

**There is no supported local / manual build for this layer.**

The only place `ScaleCloudKit` is generated and archived is inside the official **Build ScaleCloudKit** GitHub Actions workflow (`testbuildSCKit.yml`).

Typical independent usage:
- You have (or a prior dispatch produced) a `go_run_id` whose "Build ScaleCloudGo" run published `ScaleCloudGo-prebuilt`.
- You dispatch the Kit workflow, supplying that `go_run_id`.
- The Kit job downloads the Go prebuilt artifact, unpacks it under `ScaleCloudGo/prebuilt/`, then runs its own `xcodegen generate --spec ScaleCloudKit/project.yml` + `xcodebuild archive`.
- On success it publishes `ScaleCloudKit-prebuilt` (containing `NextcloudKit.framework`) for App / Wrap.

## Used by

- ScaleCloudApp (via the adapted ScaleCloudApp/ScaleCloudApp.xcodeproj copied from upstream nextcloud/ios Nextcloud.xcodeproj + our narrow edits for source roots + prebuilt NextcloudKit fileRef + FRAMEWORK_SEARCH_PATHS)
- ScaleCloudWrap (transitively)

## When to rebuild

- Any change to ScaleCloudKit/Sources (the actual fork contents)
- Changing the three SPM pins
- After a breaking ScaleCloudGo interface change

Rebuilding this layer means you will normally also want a fresh App build (and Wrap if you ship it).
