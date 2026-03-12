#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./setup.sh linux [linux-script-args...]
  ./setup.sh docker [docker-script-args...]
  ./setup.sh all [linux-script-args...] -- [docker-script-args...]

Examples:
  ./setup.sh linux --admin-user openclaw --tailscale-up ssh
  ./setup.sh docker --workspace-dir-name workspace-main
  ./setup.sh all --admin-user openclaw --tailscale-up ssh -- --workspace-dir-name workspace-main
EOF
}

MODE="${1:-}"
[[ -z "$MODE" ]] && { usage; exit 1; }
shift || true

case "$MODE" in
  linux)
    exec bash "$ROOT_DIR/linux/bootstrap-linux-tailscale.sh" "$@"
    ;;
  docker)
    cd "$ROOT_DIR/docker/bootstrap"
    exec bash ./scripts/setup-docker-openclaw.sh "$@"
    ;;
  all)
    linux_args=()
    docker_args=()
    sep=0
    for arg in "$@"; do
      if [[ "$arg" == "--" && $sep -eq 0 ]]; then
        sep=1
        continue
      fi
      if [[ $sep -eq 0 ]]; then
        linux_args+=("$arg")
      else
        docker_args+=("$arg")
      fi
    done

    bash "$ROOT_DIR/linux/bootstrap-linux-tailscale.sh" "${linux_args[@]}"
    cd "$ROOT_DIR/docker/bootstrap"
    exec bash ./scripts/setup-docker-openclaw.sh "${docker_args[@]}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 1
    ;;
esac
