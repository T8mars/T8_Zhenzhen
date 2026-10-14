# VibeX Local Source Export

This zip contains the current development source captured from the running VibeX container.
It may be a half-finished project if you downloaded it while generation was still in progress.

## Run on macOS

```bash
chmod +x vibex-local/start-macos.sh
./vibex-local/start-macos.sh
```

## Run on Linux

```bash
chmod +x vibex-local/start-linux.sh
./vibex-local/start-linux.sh
```

## Run on Windows

Double-click `vibex-local/start-windows.bat`, or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\vibex-local\start-windows.ps1
```

The app opens at `http://127.0.0.1:8000` and PocketBase runs at `http://127.0.0.1:7000`; both ports must be free before starting.
The local Vite config proxies `/__pb` to PocketBase, matching the VibeX online runtime path.

## Requirements

- Node.js 20.19+ or 22.12+
- Internet access on first run for npm/pnpm dependencies and PocketBase
- macOS/Linux: `curl` and `unzip`

PocketBase is not bundled in this zip. The start script downloads the matching PocketBase release for your platform on first run and caches it under `vibex-local/bin/`.

## Data and secrets

This export intentionally does not include `pb_data`, `.env`, logs, Claude history, `node_modules`, PocketBase binaries, or build output.
If AI features need RunningHub credentials locally, edit `.env.local` and fill only your own local key values.
Third-party capability keys (maps, payments, and similar) are stored in `project/vibex-capability-keys.json` and travel with this export. Keep that file private; do not commit it to a public repository.

Exported app id: `app-c7fc28792e814eaabdbf6806b4a76e6d`
