---
name: vibex-app-source-roundtrip
description: Use when editing source downloaded from a VibeX app and returning modified files through the VibeX Source editor. Trigger for Codex, Claude Code, Cursor, source ZIP upload, app/src, pb_hooks, preview unchanged after upload, or VibeX source round trips.
---

# VibeX App Source Roundtrip

Treat the downloaded directory as a live VibeX dev-source snapshot. Preserve its platform contract while editing, then produce upload packages whose internal paths match the selected VibeX Source-tree directory.

## Before Editing

1. Read `vibex-local/export-manifest.json`. Confirm `app_id`, `source: dev-container`, and the export time.
2. Inspect `package.json` and the existing code before choosing build commands or changing architecture.
3. Preserve `.vibex-app-type`, RunningHub login/billing integrations, app id references, and PocketBase routing.
4. Never expose or package `.env`, credentials, `pb_data`, logs, `node_modules`, `dist`, caches, or agent work directories.

## Change And Verify

Keep changes scoped to the user's request. Do not rewrite protected VibeX platform libraries merely to make local code simpler; uploads of protected files return `platform_lib` and are skipped.

Run the project's existing typecheck, tests, lint, and build in proportion to the change. Report pre-existing failures separately from failures introduced by the edit. Build output is verification evidence, not source to upload.

## Package By Upload Target

The VibeX Source editor concatenates the selected directory with every ZIP entry. It does not strip a wrapper folder.

| VibeX directory selected before upload | Local `--source` | ZIP entries must look like |
| --- | --- | --- |
| `app/src/` | `<download>/src` | `index.css`, `components/App.tsx` |
| `app/` | `<download>` | `package.json`, `src/index.css` |
| `pb_hooks/` | `<download>/pocketbase/pb_hooks` | `aigc.pb.js` |

Create one ZIP per target directory. Never put `<project-name>/src/...` in a ZIP uploaded to `app/src/`; that writes a nested unused directory and leaves the preview unchanged.

Prefer packaging only changed paths:

```bash
python3 .vibex/skills/vibex-app-source-roundtrip/scripts/package_vibex_upload.py \
  --source ./src \
  --output ../app-src-vibex-upload.zip \
  --target app/src \
  --include index.css \
  --include components/home
```

Omit `--include` only when every file under `--source` is intentionally being replaced. Place the output outside the downloaded project when practical.

## Verify The Handoff

Inspect the ZIP before giving it to the user:

```bash
python3 -m zipfile -l ../app-src-vibex-upload.zip
```

The final response must state:

- Which VibeX Source-tree directory to select.
- Which ZIP to upload and whether to choose **extract**.
- Expected written paths/count and any protected files intentionally omitted.
- Which local verification commands passed or failed.

After upload, require the result to show intended paths such as `app/src/index.css`. Treat `app/src/<project-name>/...`, unexpected skips, `PATH_FORBIDDEN`, or `INVALID_PATH` as a failed handoff and repackage before troubleshooting runtime behavior.

Correct dev-source writes should appear after a preview refresh. Public/published snapshots are separate and require a fresh audit and republish after source changes.
