#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-/home/node/.openclaw}"
WORKSPACE_DIR_NAME="${OPENCLAW_WORKSPACE_DIR_NAME:-workspace}"
WS_DIR="${STATE_DIR}/${WORKSPACE_DIR_NAME}"
SEED_ROOT="/opt/openclaw/seed/workspace"
DEFAULTS_TMPL="/opt/openclaw/openclaw.defaults.json.tmpl"
CONFIG_PATH="${STATE_DIR}/openclaw.json"

mkdir -p "$STATE_DIR" "$WS_DIR"

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ ! -e "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    echo "[init] seeded: ${dst}"
  fi
}

# Seed workspace baseline only for missing files
while IFS= read -r -d '' f; do
  rel="${f#${SEED_ROOT}/}"
  copy_if_missing "$f" "$WS_DIR/$rel"
done < <(find "$SEED_ROOT" -type f -print0)

# Seed config only if missing
if [[ ! -f "$CONFIG_PATH" ]]; then
  export OPENCLAW_MODEL_PRIMARY="${OPENCLAW_MODEL_PRIMARY:-openai-codex/gpt-5.3-codex}"
  export OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$WS_DIR}"
  export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
  envsubst < "$DEFAULTS_TMPL" > "$CONFIG_PATH"
  echo "[init] generated: $CONFIG_PATH"
fi

# Hand off to upstream default command
exec openclaw gateway
