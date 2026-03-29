#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$ROOT_DIR/index.html" "$DIST_DIR/index.html"

if [ -f "$ROOT_DIR/hello.html" ]; then
  cp "$ROOT_DIR/hello.html" "$DIST_DIR/hello.html"
fi

echo "Built Pages artifact in: $DIST_DIR"
find "$DIST_DIR" -maxdepth 2 -type f | sort
