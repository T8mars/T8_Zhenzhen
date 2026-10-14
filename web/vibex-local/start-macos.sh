#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OS="Darwin"
PB_PLATFORM="darwin"
SCRIPT_NAME="vibex-local/start-macos.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ACTUAL_OS="$(uname -s)"
if [ "$ACTUAL_OS" != "$EXPECTED_OS" ]; then
  case "$ACTUAL_OS" in
    Darwin) hint="vibex-local/start-macos.sh" ;;
    Linux) hint="vibex-local/start-linux.sh" ;;
    *) hint="vibex-local/start-windows.bat on Windows, or the script matching your OS" ;;
  esac
  echo "$SCRIPT_NAME supports $EXPECTED_OS only. Try $hint." >&2
  exit 1
fi

LOCAL_DIR="$ROOT/vibex-local"
PB_DIR="$ROOT/pocketbase"
PB_BIN="$LOCAL_DIR/bin/$PB_PLATFORM/pocketbase"
PB_LOG_DIR="$PB_DIR/logs"
mkdir -p "$PB_DIR/pb_data" "$PB_DIR/pb_hooks" "$PB_DIR/pb_migrations" "$PB_LOG_DIR" "$(dirname "$PB_BIN")"

if [ ! -f "$ROOT/.env.local" ] && [ -f "$LOCAL_DIR/.env.local.example" ]; then
  cp "$LOCAL_DIR/.env.local.example" "$ROOT/.env.local"
fi
if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi
export VIBEX_APP_ID="${VIBEX_APP_ID:-app-c7fc28792e814eaabdbf6806b4a76e6d}"

pocketbase_asset_name() {
  arch="$(uname -m)"
  case "$PB_PLATFORM:$arch" in
    linux:x86_64|linux:amd64) echo "linux_amd64.zip" ;;
    linux:aarch64|linux:arm64) echo "linux_arm64.zip" ;;
    darwin:x86_64|darwin:amd64) echo "darwin_amd64.zip" ;;
    darwin:aarch64|darwin:arm64) echo "darwin_arm64.zip" ;;
    *) echo "Unsupported $ACTUAL_OS architecture: $arch" >&2; return 1 ;;
  esac
}

ensure_pocketbase() {
  if [ -x "$PB_BIN" ]; then
    if "$PB_BIN" --version >/dev/null 2>&1; then
      return
    fi
    echo "Cached PocketBase binary is not runnable on this machine; downloading a matching release." >&2
    rm -f "$PB_BIN"
  fi
  if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    echo "PocketBase is missing. Install curl + unzip, or put pocketbase at $PB_BIN" >&2
    exit 1
  fi
  asset="$(pocketbase_asset_name)"
  tmp="$(mktemp -d)"
  url="$(curl -fsSL https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep -Eo '"browser_download_url": "[^"]+' | cut -d'"' -f4 | grep "$asset" | head -n 1)"
  if [ -z "$url" ]; then
    echo "Could not resolve PocketBase download URL for $asset" >&2
    exit 1
  fi
  echo "Downloading PocketBase for $PB_PLATFORM..."
  curl -fL "$url" -o "$tmp/pocketbase.zip"
  unzip -q "$tmp/pocketbase.zip" pocketbase -d "$tmp"
  mv "$tmp/pocketbase" "$PB_BIN"
  chmod +x "$PB_BIN"
  rm -rf "$tmp"
}

ensure_node_pm() {
  if ! command -v node >/dev/null 2>&1; then
    echo "Node.js 20.19+ or 22.12+ is required. Install Node.js, then run this script again." >&2
    exit 1
  fi
  if ! node -e "const [M,m] = process.versions.node.split('.').map(Number); process.exit((M === 20 && m >= 19) || (M === 22 && m >= 12) || M > 22 ? 0 : 1)" >/dev/null 2>&1; then
    echo "Node.js 20.19+ or 22.12+ is required by this export. Install a newer Node.js, then run this script again." >&2
    exit 1
  fi
  if [ -f pnpm-lock.yaml ]; then
    if ! command -v pnpm >/dev/null 2>&1; then
      if command -v corepack >/dev/null 2>&1; then
        corepack enable
        corepack prepare pnpm@latest --activate
      else
        echo "pnpm is required for this project. Install pnpm, then run again." >&2
        exit 1
      fi
    fi
    pnpm install
    VITE_CMD=(pnpm exec vite)
  else
    npm install
    VITE_CMD=(npx vite)
  fi
}

wait_for_pocketbase() {
  for i in $(seq 1 30); do
    if ! kill -0 "$PB_PID" >/dev/null 2>&1; then
      echo "PocketBase failed to start. Check $PB_LOG_DIR/stderr.log:" >&2
      tail -n 80 "$PB_LOG_DIR/stderr.log" >&2 2>/dev/null || true
      exit 1
    fi
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS http://127.0.0.1:7000/api/health 2>/dev/null | grep -q "API is healthy"; then
        return
      fi
    elif [ "$i" -ge 3 ]; then
      return
    fi
    sleep 1
  done
  echo "PocketBase did not become healthy at http://127.0.0.1:7000/api/health." >&2
  echo "Check that port 7000 is free, then retry. Recent stderr:" >&2
  tail -n 80 "$PB_LOG_DIR/stderr.log" >&2 2>/dev/null || true
  exit 1
}

open_local_app() {
  if [ "$ACTUAL_OS" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    open http://127.0.0.1:8000 >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open http://127.0.0.1:8000 >/dev/null 2>&1 || true
  fi
}

ensure_pocketbase

"$PB_BIN" serve --http=127.0.0.1:7000 > "$PB_LOG_DIR/stdout.log" 2> "$PB_LOG_DIR/stderr.log" &
PB_PID=$!
cleanup() {
  kill "$PB_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT
wait_for_pocketbase

ensure_node_pm

(sleep 3; open_local_app) &
echo "VibeX local app: http://127.0.0.1:8000"
echo "PocketBase:      http://127.0.0.1:7000"
exec "${VITE_CMD[@]}" --config vibex-local/vite.local.config.ts --host 127.0.0.1 --port 8000
