#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR_NAME="workspace"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-dir-name) WORKSPACE_DIR_NAME="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Orchestrator wrapper for the modular steps
sudo "$SCRIPT_DIR/10-install-docker.sh"
"$SCRIPT_DIR/20-prepare-env.sh" --workspace-dir-name "$WORKSPACE_DIR_NAME"
"$SCRIPT_DIR/30-build-image.sh"
"$SCRIPT_DIR/40-up.sh"
"$SCRIPT_DIR/50-logs.sh"

echo
echo "Done."
echo "You can now manage step-by-step scripts individually in scripts/."
