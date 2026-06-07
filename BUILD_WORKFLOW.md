# ScaleCloud Build Workflow

> **GOLDEN RULE (Hard Rule)**: All build, generation, and compilation steps in this repository are executed **exclusively inside GitHub Actions workflows**.
> `xcodegen`, `xcodebuild`, `gomobile`, `tuist generate` / `tuist build`, or any equivalent commands are **never** run from developer workstations, agent shells, or local terminals — not for reproduction, not for "just checking", not even with prebuilts present.
> The only supported way to produce a layer artifact is to dispatch one of the four canonical workflows (`testbuildSCGo.yml`, `testbuildSCKit.yml`, `testbuildSCApp.yml`, `testbuildSCWrap.yml`) on GitHub via `workflow_dispatch` (or a calling workflow).
> Humans obtain prior-layer outputs the same way workflows do (Actions artifact download + unpack into the next layer's `prebuilt/` directory) so that the *subsequent official dispatch* can see the dependency.

## Overview

To save GitHub Actions credits, we build each layer **independently** with smart prebuilt dependency detection. Each layer stores its prebuilt artifacts in its own `prebuilt/` subdirectory.

The current supported mechanism is the four per-layer GitHub workflows under `.github/workflows/` (the `testbuildSC*.yml` family). A higher layer normally consumes a prior layer's output by receiving that workflow run's artifact id as a `*_run_id` input (or by a human / scheduler placing an already-produced `*-prebuilt` tree under the appropriate `prebuilt/` folder before dispatch).

This document describes the overall layered prebuilt model and the discipline around artifacts and rebuild ordering. The precise "how to build this exact layer right now" instructions live inside the four workflow definitions themselves.

**Historical note**: Earlier versions of the tree used a Tuist-based generator surface (`Project.swift` + `Workspace.swift` + conditional post-build scripts) and a single "Build Selected Layer (Standalone)" aggregator. That approach is preserved under `tuistbackup/` for rollback and archaeology, but it is no longer the active path. All references below to Tuist-style commands are either historical descriptions or have been removed.

## Directory Structure

```
scalecloud-ios/
├── ScaleCloudGo/
│   ├── project.yml                       # xcodegen spec (historical Project.swift lives under tuistbackup/)
│   ├── prebuilt/
│   │   └── ScaleCloudGo.xcframework/     # Produced by gomobile bind inside testbuildSCGo.yml
│   └── ScaleCloudGo.xcodeproj/           # Generated inside the GitHub job
├── ScaleCloudKit/
│   ├── project.yml                       # xcodegen spec + exact upstream SPM pins
│   ├── prebuilt/
│   │   └── NextcloudKit.framework/       # Module name kept NextcloudKit for import compat
│   └── ScaleCloudKit.xcodeproj/          # Generated inside the GitHub job; references Go project
├── ScaleCloudApp/
│   ├── ScaleCloudApp.xcodeproj/          # Adapted copy of upstream nextcloud/ios Nextcloud.xcodeproj
│   │                                     # (narrow edits: source roots, NextcloudKit→prebuilt swap, FRAMEWORK_SEARCH_PATHS)
│   ├── project.yml                       # Thin secondary xcodegen spec (not authoritative for full client)
│   └── prebuilt/
│       └── ... (xcarchive or .app payload for Wrap consumption)
└── ScaleCloudWrap/
    ├── project.yml
    └── prebuilt/                         # Final deliverable (takes App prebuilt as input)
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

#### How prebuilts are seen

The Go/Kit layers use `xcodegen project.yml` with `projectReferences` pointing at the lower layer's `.xcodeproj`. The App layer (authoritative source) uses the adapted `ScaleCloudApp.xcodeproj` which contains an explicit `PBXFileReference` + `PBXBuildFile` to `../ScaleCloudKit/prebuilt/NextcloudKit.framework` plus augmented `FRAMEWORK_SEARCH_PATHS`.

When a higher layer's workflow receives a `*_run_id`:
1. It downloads the prior `*-prebuilt` artifact.
2. It materializes the contents under the conventional path (e.g. `ScaleCloudKit/prebuilt/NextcloudKit.framework`).
3. The generation step (`xcodegen generate` for Go/Kit, or simply opening the edited pbxproj for App) sees the framework in the exact location the project description expects.
4. The build proceeds exactly as if the prebuilt had been a committed tree inside the repo.

### Current Supported Build Process (GitHub Actions only)

All generation and compilation happens **inside** the dispatched GitHub workflow for that layer.

Typical flow for an independent layer build:

1. (Optional but normal) Supply the `*_run_id` input from the immediately preceding layer's successful run (for example, pass a `kit_run_id` when dispatching the App workflow).
2. The workflow job checks out the repo, downloads the named `*-prebuilt` artifact from the prior run (via `actions/download-artifact`), and materializes its contents verbatim under the expected `prebuilt/` directory in the tree (e.g. `ScaleCloudKit/prebuilt/NextcloudKit.framework`).
3. The job then runs the layer-specific generation + archive step (`xcodegen generate` and/or direct use of the adapted `ScaleCloudApp.xcodeproj`, `xcodebuild archive`, etc.) on the GitHub-hosted macOS runner. The prebuilt tree that was just unpacked is seen exactly as a committed prebuilt would be (via `projectReferences`, `FRAMEWORK_SEARCH_PATHS`, and explicit file references inside the project).
4. On success the workflow uploads both an archive artifact and a clean `*-prebuilt` artifact for the next layer to consume.

The only place these generator / compiler invocations are defined and authorized is inside the four `testbuildSC*.yml` workflow files. There are no sanctioned local equivalents.

## Build Order (IMPORTANT!)

You **must** build from bottom to top:

### 1. Build ScaleCloudGo (First - No dependencies)

**Via GitHub Actions (the only supported path)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudGo"** (file: `testbuildSCGo.yml`)
3. Click **"Run workflow"** (workflow_dispatch)
4. (Optional) If you already have a prior Go run, you do **not** supply anything — Go is the bottom layer.
5. Click **"Run workflow"**

**What it builds**: Go framework with Tailscale proxy using `gomobile bind -target=ios` (the ONLY workflow permitted to install Go + gomobile)

**Output**: 
- `ScaleCloudGo-prebuilt` artifact (unpacked form ready for Kit/App)
- `ScaleCloudGo-xcarchive` (for records)

**Output location inside repo tree (when materialized)**: `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/`

**Requirements inside the job**: Go 1.26 + gomobile (installed once by this workflow)

To commit the prebuilt for long-term use (or for developers who do not want to rely on artifact expiry):
1. After success, download the `ScaleCloudGo-prebuilt` artifact from the run.
2. Unpack so its contents land under `ScaleCloudGo/prebuilt/`.
3. `git add ScaleCloudGo/prebuilt/ && git commit -m "prebuilt: ScaleCloudGo from <run>" && git push`

Higher layers will then see the tree on normal checkout OR they can pass the produced `go_run_id` to their own dispatch (the consuming SC* workflow will do the `download-artifact + materialize` step for you).

### 2. Build ScaleCloudKit (Second - Requires Go)

**Prerequisites**: ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions (independent layer; only Go toolchain cost if you provide a `go_run_id`)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudKit"** (file: `testbuildSCKit.yml`)
3. Click **"Run workflow"**
4. (Recommended) Paste the run ID of a prior successful **Build ScaleCloudGo** into the `go_run_id` input.
5. Click **"Run workflow"**

**What it builds**: Fork of NextcloudKit (module name kept as `NextcloudKit` for `import` compatibility with transplanted iOSClient/Brand sources) linked against a ScaleCloudGo prebuilt. No Go toolchain is installed when `go_run_id` is supplied.

**Output**:
- `ScaleCloudKit-prebuilt` (contains `NextcloudKit.framework`)
- `ScaleCloudKit-xcarchive`

**When materialized by the next layer or by hand**: `ScaleCloudKit/prebuilt/NextcloudKit.framework/`

Key point: the xcodegen project for Kit (`project.yml`) pins exactly the same Alamofire/SwiftyJSON/SwiftyXMLParser versions as upstream NextcloudKit's `Package.swift`, and declares the Go layer via `projectReferences`.

### 3. Build ScaleCloudApp (Third - Requires Go + Kit)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudKit/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions (the authoritative build of the full client)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudApp"** (file: `testbuildSCApp.yml`)
3. Click **"Run workflow"**
4. (Recommended) Supply `kit_run_id` (and transitively `go_run_id` if you have it) from prior successful builds.
5. Click **"Run workflow"**

**What it builds**: The complete iOS application (all iOSClient/ + Brand/ sources + assets + entitlements) linked against the prebuilt `NextcloudKit.framework` (ScaleCloudKit). Dozens of third-party libraries (RealmSwift, LucidBanner, MobileVLCKit, etc.) are declared exactly as they are in the upstream `nextcloud/ios` project; only the NextcloudKit reference and a couple of search-path/root adjustments were edited.

**Output**:
- `ScaleCloudApp-prebuilt`
- `ScaleCloudApp-xcarchive`

**Authoritative project description**: `ScaleCloudApp/ScaleCloudApp.xcodeproj/` (a narrow-edit copy of `nextcloud/ios/Nextcloud.xcodeproj`). The thin secondary `project.yml` is only used for quick projectReference consumers.

A consuming Wrap dispatch or a human doing data movement unpacks the artifact so that the tree contains the expected payload under `ScaleCloudApp/prebuilt/`.

### 4. Build ScaleCloudWrap (Last - Requires All)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudKit/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudApp/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions (distribution / embedding wrapper)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudWrap"** (file: `testbuildSCWrap.yml`)
3. Click **"Run workflow"**
4. (Recommended) Supply `app_run_id` (and the transitive lower run ids if you have them).
5. Click **"Run workflow"**

**What it builds**: The optional top wrapper / distribution layer. It consumes a fully-produced App payload (`.app` or equivalent from the xcarchive) placed under `ScaleCloudApp/prebuilt/` via the normal download+materialize step or by a prior human unpack of a committed prebuilt.

**Output**: `ScaleCloudWrap-prebuilt` (and its xcarchive). The contents depend on what the Wrap target embeds; it is the final deliverable for most external distribution flows.

**Note**: ScaleCloudWrap is not yet heavily exercised; the pattern is identical to the others.

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

## Credit and Time Savings via Independent Layer Builds

Because each layer is built by its own dedicated GitHub workflow, and higher layers normally receive a prior layer's output via an artifact download step (or a pre-committed `prebuilt/` tree), most dispatches do **not** need to reinstall or re-execute the toolchains of layers below them.

Typical savings:
- A documentation-only or Brand-asset change in the App layer can be built by dispatching the App workflow while giving it a `kit_run_id` (and transitively a `go_run_id`). The Go and Kit toolchains are never installed on that runner.
- A change that only touches `ScaleCloudKit/Sources/` can dispatch the Kit workflow (providing only a `go_run_id`). The full Go + gomobile work is skipped.
- Only changes that actually touch the Go/Tailscale bridge require dispatching the Go workflow (the sole workflow that pays the "install Go 1.26 + gomobile" cost).

The four SC* workflows are deliberately factored so that the common happy path (provide the prior run id) skips the lower toolchain installation and build steps entirely.

## Local / Workstation Usage (Data Movement Only)

You may obtain artifacts produced by prior workflow runs (either by downloading them from the Actions "Artifacts" section of a run, or by letting a higher-layer workflow do the `actions/download-artifact` step for you).

You may unpack those artifacts into the appropriate `prebuilt/` directory in a local clone. This is purely a data-movement / input-preparation step so that the *next* GitHub dispatch of the consuming layer's workflow will see a usable prebuilt.

**You do not run any generation or compilation commands on your machine.** There are no supported `tuist`, `xcodegen`, `xcodebuild`, or `gomobile` reproduction steps. All such work is executed exclusively on GitHub-hosted runners as part of the four canonical workflows.

If you need a refreshed artifact for a layer, dispatch that layer's workflow on GitHub (supplying prior run ids as needed). The resulting `*-prebuilt` artifact is the artifact of record.

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

This surfaces inside a GitHub Actions run when the layer's declared external packages (from its `project.yml` or the adapted `project.pbxproj`) were not resolved by the job before compilation. The workflows that need SPM packages normally resolve them as part of the job.

**Solution**: Look at the failing workflow run log for the specific layer (`testbuildSCKit.yml`, `testbuildSCApp.yml`, etc.). The job is responsible for ensuring dependencies are present (via checkout of `Package.resolved`, or via the prebuilt framework that already embeds them). Re-dispatch after confirming the prior layer's `*-prebuilt` artifact was correctly materialized (or let the workflow download it via the `*_run_id` input).

### Build Fails: Framework Not Found (prebuilt missing)

The consuming layer's generation or link step cannot find the framework it was told to expect under `../<LowerLayer>/prebuilt/`.

Check (inside the Actions log for that run, or locally before dispatch):

1. For a Kit build: does `ScaleCloudGo/prebuilt/` contain the Go output after materialization/download step?
2. For an App build: does `ScaleCloudKit/prebuilt/` contain `NextcloudKit.framework` (note the name — deliberate for upstream import compatibility)?
3. Was the correct `*_run_id` supplied to the dispatch, or did a human forget to unpack the prior artifact before pushing a branch that triggers the consuming workflow?

The four SC* workflows are responsible for downloading prior `*-prebuilt` artifacts (when a run id is supplied) and placing them under the expected tree before they invoke their own generation step.

### Workflow Fails Immediately

Check the "Verify prebuilt dependencies" step in the Actions log. It tells you exactly which dependencies are missing.

## FAQ

**Q: Can a single workflow run build multiple layers bottom-to-top?**

A: No. The four canonical per-layer workflows (`testbuildSCGo.yml`, `testbuildSCKit.yml`, `testbuildSCApp.yml`, `testbuildSCWrap.yml`) each build exactly one layer. You chain them by passing `*_run_id` inputs (or by committing the `*-prebuilt` tree and dispatching the next layer afterwards). All generation and compilation steps occur only inside one of these four dispatched jobs.

**Q: What if I want a completely fresh bottom-up rebuild of everything?**

A: Dispatch Go (with no `go_run_id`), then dispatch Kit giving it the Go run id just produced, then App giving it the Kit run id, then Wrap giving it the App run id. You do not need to commit the intermediate prebuilts between dispatches if you are only using the short-lived artifacts within one investigation, but for ongoing development you normally commit the `*-prebuilt` trees so that future dispatches (and other humans) can refer to them by run id or see them after a normal `git checkout`.

**Q: Do I need to commit prebuilts after every CI build?**

A: Not strictly — you can chain dispatches using the run ids of the just-completed runs. Committing the `*-prebuilt` trees (or at least the critical ones) makes the artifacts survive past the short GitHub retention period and makes it easy for anyone to resume work later without having to hunt through old run logs.

**Q: Can I (or should I) delete the `prebuilt/` folders locally to save space?**

A: Yes. They are large binary trees. The model is: either they are committed (and you can `git checkout` / LFS-pull them), or the next workflow dispatch you care about will download the exact version it needs via the `*_run_id` input and materialize it under the folder for the duration of that job. Local `prebuilt/` contents are conveniences / caches, not authoritative. Use Git LFS if you decide to track the committed prebuilts (`git lfs track "*/prebuilt/**"`).

**Q: What do the GitHub Actions `*-prebuilt` artifacts contain?**

A: The tree that the next layer expects to find under its `../<LowerLayer>/prebuilt/` path after a download+unpack step. For Go this is typically the gomobile-produced xcframework (or framework). For Kit it is `NextcloudKit.framework` (intentionally named for import compatibility with the large upstream-derived client sources). For App it is usually the xcarchive / Products layout. The unpack step performed by the consuming workflow (or a human before dispatch) makes the layout identical to a committed prebuilt.

**Q: Why do the specs use project references / search paths that point at prebuilt/ instead of just committing the final built products into the higher layer?**

A: It keeps each layer's build job small and focused, makes the dependency handoff explicit and auditable, and lets a higher layer's workflow stay "maximally compatible" with the upstream project descriptions (which expect to link by framework name and search path) without having to embed another layer's entire build graph. It is the same principle that the old Tuist `.project()` + conditional-post-build design was trying to achieve, just realized with ordinary xcodegen / pbxproj mechanisms and ordinary GitHub artifact download steps.

**Q: Do I need Go installed locally?**

A: Only if you're modifying Go code AND don't have `ScaleCloudGo/prebuilt/`. If the prebuilt exists, the post-build script uses it and Go isn't needed.
