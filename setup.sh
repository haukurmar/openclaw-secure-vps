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
  ./setup.sh docker --workspace-dir-name workspace-main --state-user openclaw
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

    # If docker state user is not explicitly set, inherit from linux --admin-user in all mode.
    docker_has_state_user=0
    docker_has_state_dir=0
    for ((i=0; i<${#docker_args[@]}; i++)); do
      [[ "${docker_args[$i]}" == "--state-user" ]] && docker_has_state_user=1
      [[ "${docker_args[$i]}" == "--state-dir" ]] && docker_has_state_dir=1
    done

    linux_admin_user=""
    for ((i=0; i<${#linux_args[@]}; i++)); do
      if [[ "${linux_args[$i]}" == "--admin-user" && $((i+1)) -lt ${#linux_args[@]} ]]; then
        linux_admin_user="${linux_args[$((i+1))]}"
        break
      fi
    done

    if [[ $docker_has_state_user -eq 0 && $docker_has_state_dir -eq 0 && -n "$linux_admin_user" ]]; then
      docker_args+=(--state-user "$linux_admin_user")
    fi

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
