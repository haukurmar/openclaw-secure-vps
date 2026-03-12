#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR_NAME="workspace"
STATE_USER="openclaw"
STATE_DIR=""
SKIP_INSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-dir-name) WORKSPACE_DIR_NAME="$2"; shift 2 ;;
    --state-user) STATE_USER="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Orchestrator wrapper for the modular steps
if [[ $SKIP_INSTALL -eq 1 ]]; then
  echo "[ok] skipping Docker install step (--skip-install)"
else
  if [[ $EUID -eq 0 ]]; then
    "$SCRIPT_DIR/10-install-docker.sh"
  else
    sudo "$SCRIPT_DIR/10-install-docker.sh"
  fi
fi

prepare_args=(
  --workspace-dir-name "$WORKSPACE_DIR_NAME"
  --state-user "$STATE_USER"
)
if [[ -n "$STATE_DIR" ]]; then
  prepare_args+=(--state-dir "$STATE_DIR")
fi

"$SCRIPT_DIR/20-prepare-env.sh" "${prepare_args[@]}"
"$SCRIPT_DIR/30-build-image.sh"
"$SCRIPT_DIR/40-up.sh"
"$SCRIPT_DIR/50-logs.sh"

echo
echo "Done."
echo "You can now manage step-by-step scripts individually in scripts/."
