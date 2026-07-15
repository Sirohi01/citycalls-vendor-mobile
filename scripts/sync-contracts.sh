#!/usr/bin/env bash
# Pulls the canonical OpenAPI spec from citycalls-docs into openapi/citycalls.yaml
# for local Dart model codegen. Per docs/manish/01-project-and-repository-setup.md §3.
set -euo pipefail

DOCS_REPO_PATH="${CITYCALLS_DOCS_PATH:-../docs}"
SOURCE="$DOCS_REPO_PATH/openapi/citycalls.yaml"
DEST="openapi/citycalls.yaml"

mkdir -p openapi

if [ -f "$SOURCE" ]; then
  cp "$SOURCE" "$DEST"
  echo "[sync-contracts] copied $SOURCE -> $DEST"
else
  echo "[sync-contracts] $SOURCE not found — set CITYCALLS_DOCS_PATH or create the spec first" >&2
  exit 1
fi
