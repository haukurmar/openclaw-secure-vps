#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR_NAME="workspace"
STATE_USER="openclaw"
STATE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-dir-name) WORKSPACE_DIR_NAME="$2"; shift 2 ;;
    --state-user) STATE_USER="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$STATE_DIR" ]]; then
  STATE_DIR="/home/${STATE_USER}/.openclaw"
fi

if [[ ! -f "$STACK_DIR/.env" ]]; then
  cp "$STACK_DIR/.env.example" "$STACK_DIR/.env"
  echo "[ok] created $STACK_DIR/.env from template"
else
  echo "[ok] existing .env found"
fi

# Update env values
sed -i -E "s|^OPENCLAW_WORKSPACE_DIR_NAME=.*|OPENCLAW_WORKSPACE_DIR_NAME=${WORKSPACE_DIR_NAME}|" "$STACK_DIR/.env"
sed -i -E "s|^OPENCLAW_WORKSPACE=.*|OPENCLAW_WORKSPACE=/home/node/.openclaw/${WORKSPACE_DIR_NAME}|" "$STACK_DIR/.env"
sed -i -E "s|^OPENCLAW_STATE_DIR=.*|OPENCLAW_STATE_DIR=${STATE_DIR}|" "$STACK_DIR/.env"

# Ensure bind-mount source exists to avoid docker compose mkdir permission errors
if [[ $EUID -eq 0 ]]; then
  mkdir -p "$STATE_DIR"
else
  sudo mkdir -p "$STATE_DIR"
fi

if id -u "$STATE_USER" >/dev/null 2>&1; then
  if [[ $EUID -eq 0 ]]; then
    chown -R "$STATE_USER:$STATE_USER" "$STATE_DIR"
  else
    sudo chown -R "$STATE_USER:$STATE_USER" "$STATE_DIR"
  fi
else
  echo "[warn] state user '$STATE_USER' does not exist, skipped chown"
fi

echo "[ok] workspace dir set to: ${WORKSPACE_DIR_NAME}"
echo "[ok] state dir set to: ${STATE_DIR}"
echo "Edit $STACK_DIR/.env if needed before deploy."
