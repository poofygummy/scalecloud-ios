# ScaleCloud Build Workflow

> **GOLDEN RULE (Hard Rule)**: All build, generation, and compilation steps in this repository are executed **exclusively inside GitHub Actions workflows**.
> `xcodegen`, `xcodebuild`, `gomobile`, `tuist generate` / `tuist build`, or any equivalent commands are **never** run from developer workstations, agent shells, or local terminals — not for reproduction, not for "just checking", not even with prebuilts present.
> The only supported way to produce a layer artifact is to dispatch one of the four canonical workflows (`testbuildSCGo.yml`, `testbuildSCKit.yml`, `testbuildSCApp.yml`, `testbuildSCWrap.yml`) on GitHub via `workflow_dispatch` (or a calling workflow).
> Humans obtain prior-layer outputs by going to the GitHub Actions run page of a prior layer, downloading the `*-prebuilt` artifact from the Artifacts section, and manually unpacking it into the appropriate `<layer>/prebuilt/` directory in their clone. Only after that manual data-movement step do they dispatch the next layer's workflow. The workflows themselves never perform cross-run artifact downloads.

## Overview

To save GitHub Actions credits, we build each layer **independently** with smart prebuilt dependency detection. Each layer stores its prebuilt artifacts in its own `prebuilt/` subdirectory.

The current supported mechanism is the four per-layer GitHub workflows under `.github/workflows/` (the `testbuildSC*.yml` family). A higher layer consumes a prior layer's output only when a human has already downloaded the prior `*-prebuilt` artifact from the GitHub UI and manually unpacked its contents under the appropriate `<layer>/prebuilt/` directory in the clone before dispatching the higher workflow. The workflows themselves perform no cross-run artifact fetching.

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

You (a human) obtain prior-layer outputs the same way every layer build has always worked:
- After a successful dispatch you go to the GitHub Actions run page → Artifacts.
- Download the relevant `*-prebuilt` zip.
- Unpack it locally into your clone so the contents land under the expected directory, e.g. `ScaleCloudKit/prebuilt/NextcloudKit.framework` (or `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework`, etc.).
- Then (and only then) you dispatch the next layer's workflow.
The workflow itself does **no** cross-run artifact downloads. It simply checks that the required prebuilt tree is already sitting in the repo checkout when the job starts. If it is not there, the job fails fast with a clear instruction.

### Current Supported Build Process (GitHub Actions only)

All generation and compilation happens **inside** the dispatched GitHub workflow for that layer.

The supported flow for an independent layer build (the only supported flow):

1. Dispatch the bottom-most layer you need (or use a prior committed prebuilt tree).
2. After it succeeds, go to that run in the GitHub UI, download the `*-prebuilt` artifact.
3. Unpack the artifact contents into your clone so they sit under the correct `<Layer>/prebuilt/` directory (the exact layout the next layer's project reference / pbxproj / search paths expect).
4. Dispatch the next higher layer workflow. That job will verify the prebuilt(s) are present and, if they are, will run only its own generation + compile step. It will never reach out to previous runs itself.
5. Repeat.

The only place any generation or compilation code runs is inside one of the four `testbuildSC*.yml` workflow jobs after you have manually arranged the prebuilts in the tree. There are no sanctioned local equivalents and no automatic cross-workflow artifact fetching inside the jobs.

## Build Order (IMPORTANT!)

You **must** build from bottom to top:

### 1. Build ScaleCloudGo (First - No dependencies)

**Via GitHub Actions (the only supported path)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudGo"** (file: `testbuildSCGo.yml`)
3. Click **"Run workflow"** (workflow_dispatch). There are no inputs for prior layers (Go is the root).
4. Click **"Run workflow"**

**What it builds**: Go framework with Tailscale proxy using `gomobile bind -target=ios` (the ONLY workflow permitted to install Go + gomobile)

**Output**: 
- `ScaleCloudGo-prebuilt` artifact
- `ScaleCloudGo-xcarchive` (for records)

The prebuilt artifact, once you manually download it from the run's Artifacts and unpack it into your clone, produces the tree under `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework/` (or .framework) that higher layers expect to find.

To make a lower layer permanently available without having to keep re-downloading artifacts:
1. After the run succeeds, download the `ScaleCloudGo-prebuilt` artifact.
2. Unpack it so the files end up under `ScaleCloudGo/prebuilt/` in your working copy.
3. Commit and push:
   ```bash
   git add ScaleCloudGo/prebuilt/
   git commit -m "prebuilt: ScaleCloudGo from run <id>"
   git push
   ```
Any later dispatch of Kit/App/Wrap (on a checkout that contains this tree) will see the prebuilt and skip Go work. The workflows themselves never perform artifact downloads across runs.

### 2. Build ScaleCloudKit (Second - Requires Go)

**Prerequisites**: ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions (independent layer build)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudKit"** (file: `testbuildSCKit.yml`)
3. Click **"Run workflow"**
   - Before doing this you **must** have already downloaded the `ScaleCloudGo-prebuilt` artifact from a prior Go run (or have it committed) and unpacked it so that `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework` (or .framework) exists in the tree.
4. Click **"Run workflow"**

**What it builds**: Fork of NextcloudKit (module name kept as `NextcloudKit` for `import` compatibility with transplanted iOSClient/Brand sources) that links against whatever ScaleCloudGo prebuilt it finds under `ScaleCloudGo/prebuilt/`.

**Output**:
- `ScaleCloudKit-prebuilt` (contains `NextcloudKit.framework`)
- `ScaleCloudKit-xcarchive`

The workflow job itself will refuse to run (fast error) if it does not see the Go prebuilt already placed in the tree. It does not reach out to other workflow runs.

Key point: the xcodegen project for Kit (`project.yml`) pins exactly the same Alamofire/SwiftyJSON/SwiftyXMLParser versions as upstream NextcloudKit's `Package.swift`, and declares the Go layer via `projectReferences`.

### 3. Build ScaleCloudApp (Third - Requires Go + Kit)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudKit/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions (the authoritative build of the full client)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudApp"** (file: `testbuildSCApp.yml`)
3. Click **"Run workflow"**
   - Before dispatching you **must** have manually placed the outputs of the two lower layers into the tree:
     - `ScaleCloudGo/prebuilt/...` (from a previous Go run's prebuilt artifact)
     - `ScaleCloudKit/prebuilt/NextcloudKit.framework` (from a previous Kit run's prebuilt artifact)
4. Click **"Run workflow"**

**What it builds**: The complete iOS application (all iOSClient/ + Brand/ sources + assets + entitlements) linked against the prebuilt `NextcloudKit.framework` (ScaleCloudKit) that you placed at `ScaleCloudKit/prebuilt/`. Dozens of third-party libraries (RealmSwift, LucidBanner, MobileVLCKit, etc.) are declared exactly as they are in the upstream `nextcloud/ios` project; only the NextcloudKit reference and a couple of search-path/root adjustments were edited.

**Output**:
- `ScaleCloudApp-prebuilt`
- `ScaleCloudApp-xcarchive`

**Authoritative project description**: `ScaleCloudApp/ScaleCloudApp.xcodeproj/` (a narrow-edit copy of `nextcloud/ios/Nextcloud.xcodeproj`). The thin secondary `project.yml` is only used for quick projectReference consumers.

When you want to feed this to Wrap (or re-use it later), you download the `ScaleCloudApp-prebuilt` artifact from the run and unpack it into `ScaleCloudApp/prebuilt/` in your clone by hand.

### 4. Build ScaleCloudWrap (Last - Requires All)

**Prerequisites**: 
- ✅ `ScaleCloudGo/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudKit/prebuilt/` must exist (committed and pushed)
- ✅ `ScaleCloudApp/prebuilt/` must exist (committed and pushed)

**Via GitHub Actions (distribution / embedding wrapper)**:
1. Go to **Actions** tab
2. Select **"Build ScaleCloudWrap"** (file: `testbuildSCWrap.yml`)
3. Click **"Run workflow"**
   - Before dispatching you must manually ensure the App payload you want to wrap is present: unpack a prior `ScaleCloudApp-prebuilt` artifact (or a committed tree) so that the expected app bundle / xcarchive products tree is under `ScaleCloudApp/prebuilt/`.
4. Click **"Run workflow"**

**What it builds**: The optional top wrapper / distribution layer. It consumes whatever App payload you have already placed for it under `ScaleCloudApp/prebuilt/`.

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

Because each layer is its own tiny GitHub workflow and higher layers only ever look at pre-placed trees under `*/prebuilt/`, most dispatches do **not** pay for toolchains or compilation of layers below them.

Typical pattern for savings:
- You already ran Go once. You download its `ScaleCloudGo-prebuilt` artifact once and unpack it (or commit it). Future Kit, App, and Wrap dispatches on clean checkouts that contain that tree, or after you manually unpack it again, never install Go or run gomobile.
- You change only something in `ScaleCloudKit/Sources/`. You make sure a Go prebuilt tree is sitting in `ScaleCloudGo/prebuilt/`, then dispatch only the Kit workflow. Go work is skipped entirely.
- You only touch Brand assets or iOSClient UI, App layer sources, etc. You manually ensure both lower prebuilts are in their `prebuilt/` directories, dispatch only the App workflow. Go + Kit toolchains and compilation are never executed on that runner.

The cost control comes from the human doing the minimal data-movement step (one download + unzip into the right prebuilt dir) between independent dispatches, instead of every build re-executing the entire chain.

## Local / Workstation Usage (Data Movement Only)

The only thing you ever do on your machine is move artifacts around:
- After a workflow run succeeds, go to its Artifacts section and download the `*-prebuilt` zip you care about.
- Unzip it into your clone so that the extracted tree ends up under the correct `<Layer>/prebuilt/` directory (e.g. the zip contains a `ScaleCloudKit/prebuilt/NextcloudKit.framework` layout; after unzip `ScaleCloudKit/prebuilt/NextcloudKit.framework` must exist in the root of your checkout).
- Then dispatch the next higher workflow. That dispatch only verifies the prebuilts are already there.

**You do not run any generation or compilation commands on your machine.** There are no supported `tuist`, `xcodegen`, `xcodebuild`, or `gomobile` reproduction steps. All actual build work is executed exclusively on GitHub-hosted runners inside the four canonical `testbuildSC*.yml` jobs.

If you need a fresh artifact for a layer, dispatch that layer's workflow (after manually arranging any lower prebuilts it needs). The `*-prebuilt` artifact it publishes is the only authoritative output.

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

**Solution**: Look at the failing workflow run log for the specific layer (`testbuildSCKit.yml`, `testbuildSCApp.yml`, etc.). The job has a short "Verify ... prebuilt is present" step at the very beginning that tells you exactly what tree it expected to find and did not. You fix it by downloading the matching prebuilt artifact from the prior layer's run and manually unpacking it into the right place in your tree, then re-dispatch.

### Build Fails: Framework Not Found (prebuilt missing)

The consuming layer's generation or link step cannot find the framework it was told to expect under `../<LowerLayer>/prebuilt/`.

Check (inside the Actions log for that run, or locally before dispatch):

1. For a Kit build: does `ScaleCloudGo/prebuilt/` contain the Go output after materialization/download step?
2. For an App build: does `ScaleCloudKit/prebuilt/` contain `NextcloudKit.framework` (note the name — deliberate for upstream import compatibility)?
3. Did a human forget to download the prior `*-prebuilt` artifact from the GitHub run page and manually unpack it under the correct `<LowerLayer>/prebuilt/` directory before dispatching?

The human is responsible for downloading the prior `*-prebuilt` artifact from the GitHub UI and manually placing its contents under the expected `<Layer>/prebuilt/` directory before dispatching the consuming workflow. The workflows only verify presence; they do not download anything from other runs.

### Workflow Fails Immediately

Check the "Verify prebuilt dependencies" step in the Actions log. It tells you exactly which dependencies are missing.

## FAQ

**Q: Can a single workflow run build multiple layers bottom-to-top?**

A: No. The four canonical per-layer workflows each build exactly one layer. You chain them by hand: after layer N finishes you download its `*-prebuilt` artifact, unpack it into the correct `<N>/prebuilt/` dir(s) in your clone, then dispatch layer N+1. All generation and compilation steps occur only inside one of these four dispatched jobs.

**Q: What if I want a completely fresh bottom-up rebuild of everything?**

A: Dispatch only Go. After it succeeds, download its prebuilt artifact and unpack it into `ScaleCloudGo/prebuilt/`. Then dispatch only Kit. After it succeeds, download its prebuilt and unpack into `ScaleCloudKit/prebuilt/`. Repeat for App then Wrap if needed. You do not need to commit the trees between steps if you are just experimenting in one session, but for any realistic workflow you will usually commit the prebuilt trees (or at least the important ones) so that clean clones + manual unpack or git checkout already have what higher dispatches need.

**Q: Do I need to commit prebuilts after every CI build?**

A: Not strictly — as long as you keep the browser tab / Actions run page open you can download the artifact and manually unpack it into the next layer's prebuilt dir for an immediate follow-up dispatch. For anything that will live longer than the artifact retention window, or that other people / future you on another machine will need, you commit the unpacked prebuilt trees (or at least the ones you treat as "golden").

**Q: Can I (or should I) delete the `prebuilt/` folders locally to save space?**

A: Yes. They are large binary trees. The model is: either a prebuilt tree is committed in the repo (checkout or LFS will bring it back), or you manually download the artifact you need from a prior run's Artifacts list and unpack it into the right `<Layer>/prebuilt/` dir right before you dispatch the consuming layer. Local prebuilt contents are just a cache / staging area that you control by hand. Use Git LFS if the committed prebuilts get big (`git lfs track "*/prebuilt/**"`).

**Q: What do the GitHub Actions `*-prebuilt` artifacts contain?**

A: Exactly the tree that you (the human) should unpack into the corresponding `<LowerLayer>/prebuilt/` directory in your clone so that the next layer's project reference, PBXFileReference + FRAMEWORK_SEARCH_PATHS, or explicit prebuilt guard will find it. For Go: usually `ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework` (or .framework). For Kit: `ScaleCloudKit/prebuilt/NextcloudKit.framework`. For App: whatever payload the Wrap target or distribution step expects under `ScaleCloudApp/prebuilt/`. The final layout after your manual unzip must be identical to what a committed prebuilt tree would look like.

**Q: Why do the specs use project references / search paths that point at prebuilt/ instead of just committing the final built products into the higher layer?**

A: It keeps each layer's build job small and focused, makes the handoff between layers explicit (human unpacks artifact into prebuilt/ → next dispatch just sees it), and lets the higher layers stay compatible with how the upstream projects (and the adapted pbxproj) declare framework dependencies — by name and search path — without forcing every build to recompile everything below it.

**Q: Do I need Go installed locally?**

A: Only if you're modifying Go code AND don't have `ScaleCloudGo/prebuilt/`. If the prebuilt exists, the post-build script uses it and Go isn't needed.
