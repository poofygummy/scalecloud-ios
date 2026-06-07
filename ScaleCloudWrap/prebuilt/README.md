# ScaleCloudWrap Prebuilt

Top (optional) distribution / embedding wrapper layer. It can take a fully-built App (ScaleCloudApp) artifact as its input.

## CI independent usage

Workflow: **Build ScaleCloudWrap** (testbuildSCWrap.yml)

Optional inputs:
- `app_run_id`: run ID of a previous "Build ScaleCloudApp" that published `ScaleCloudApp-prebuilt`. The Wrap job will fetch it and stage under `ScaleCloudApp/prebuilt/`.
- With an App artifact present the workflow can avoid regenerating Go, Kit, and the entire iOSClient/ tree.

## Expected handoff layout

After a download-artifact + materialize step (or a manual copy), the tree should contain whatever the Wrap target embeds — typically an .app bundle or xcarchive Products tree from the App layer.

**There is no supported local build for this layer.**

Wrap exists to take a fully-built App artifact (produced by the App workflow) as its input. The only place the Wrap target is generated and archived is inside the official **Build ScaleCloudWrap** GitHub Actions workflow (`testbuildSCWrap.yml`).

You materialize an App prebuilt (by supplying an `app_run_id` to the Wrap dispatch, or by manually unpacking a prior `ScaleCloudApp-prebuilt` artifact under `ScaleCloudApp/prebuilt/`) and then dispatch Wrap.

The small `ScaleCloudWrap/project.yml` is only ever interpreted inside that GitHub job.

## When to rebuild

- After any change in Wrap sources, or
- When shipping a new App (or any lower layer that affects the embedded payload).

Nothing upstream of this layer exists in the Nextcloud ecosystem; this is a pure ScaleCloud packaging detail.
