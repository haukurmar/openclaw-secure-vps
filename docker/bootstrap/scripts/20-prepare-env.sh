#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR_NAME="workspace"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-dir-name) WORKSPACE_DIR_NAME="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$STACK_DIR/.env" ]]; then
  cp "$STACK_DIR/.env.example" "$STACK_DIR/.env"
  echo "[ok] created $STACK_DIR/.env from template"
else
  echo "[ok] existing .env found"
fi

# Update workspace naming in .env
sed -i -E "s|^OPENCLAW_WORKSPACE_DIR_NAME=.*|OPENCLAW_WORKSPACE_DIR_NAME=${WORKSPACE_DIR_NAME}|" "$STACK_DIR/.env"
sed -i -E "s|^OPENCLAW_WORKSPACE=.*|OPENCLAW_WORKSPACE=/home/node/.openclaw/${WORKSPACE_DIR_NAME}|" "$STACK_DIR/.env"

echo "[ok] workspace dir set to: ${WORKSPACE_DIR_NAME}"
echo "Edit $STACK_DIR/.env if needed before deploy."
