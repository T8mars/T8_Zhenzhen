#!/usr/bin/env python3
"""Create a flat ZIP for a selected VibeX source-editor directory."""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path


EXCLUDED_DIRS = {
    ".git", ".superpowers", ".vite", ".vibex", "__pycache__",
    "coverage", "dist", "node_modules",
    # VibeX export-only additions living at the download root; they are not part
    # of the app/ tree and must never be uploaded to the Source editor.
    ".cursor", "pocketbase", "vibex-local",
}
# .gitignore is rejected by the Source editor server side; skip it up front.
EXCLUDED_NAMES = {".DS_Store", ".gitignore", "AGENTS.md", "CLAUDE.md", "export-manifest.json"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a ZIP relative to the selected VibeX upload directory."
    )
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--include", action="append", default=[])
    parser.add_argument("--target", default="app/src")
    return parser.parse_args()


def is_excluded(relative: Path) -> bool:
    return (
        any(part in EXCLUDED_DIRS for part in relative.parts)
        or relative.name in EXCLUDED_NAMES
        or relative.suffix == ".log"
    )


def collect_files(source: Path, includes: list[str], output: Path) -> list[Path]:
    requested = [source / item for item in includes] if includes else [source]
    files: set[Path] = set()
    for item in requested:
        resolved = item.resolve()
        if resolved != source and source not in resolved.parents:
            raise ValueError(f"Included path escapes --source: {item}")
        if not resolved.exists():
            raise ValueError(f"Included path does not exist: {item}")
        candidates = [resolved] if resolved.is_file() else resolved.rglob("*")
        for candidate in candidates:
            if not candidate.is_file():
                continue
            relative = candidate.relative_to(source)
            if not is_excluded(relative) and candidate.resolve() != output:
                files.add(candidate)
    return sorted(files, key=lambda item: item.relative_to(source).as_posix())


def main() -> int:
    args = parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    if not source.is_dir():
        raise ValueError(f"--source is not a directory: {source}")
    files = collect_files(source, args.include, output)
    if not files:
        raise ValueError("No files selected for upload.")

    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for item in files:
            archive.write(item, item.relative_to(source).as_posix())

    print(f"Created {output} with {len(files)} file(s) for VibeX target {args.target}/")
    for item in files:
        print(item.relative_to(source).as_posix())
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
