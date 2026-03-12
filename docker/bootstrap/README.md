# OpenClaw Docker Bootstrap (Phase 1 + 2)

This bundle gives you:

- **Phase 1:** Host Docker setup + OpenClaw container bring-up
- **Phase 2:** Config layering + idempotent seed initialization

## Files

- `scripts/setup-docker-openclaw.sh` — wrapper that runs modular steps
- `scripts/10-install-docker.sh`
- `scripts/20-prepare-env.sh`
- `scripts/30-build-image.sh`
- `scripts/40-up.sh`
- `scripts/50-logs.sh`
- `compose.yaml` — local stack definition
- `Dockerfile` — wrapper image over official OpenClaw image
- `scripts/entrypoint-init.sh` — first-run seed/init logic
- `openclaw.defaults.json.tmpl` — safe baseline config (no secrets)
- `seed/workspace/*` — baseline persona + memory v2 structure

## Quick start

```bash
cd ./docker/bootstrap
sudo ./scripts/setup-docker-openclaw.sh --workspace-dir-name workspace --state-user openclaw
```

Example custom workspace name:

```bash
sudo ./scripts/setup-docker-openclaw.sh --workspace-dir-name workspace-main --state-user openclaw

# or explicit state path override
sudo ./scripts/setup-docker-openclaw.sh --state-dir /home/openclaw/.openclaw
```

## Layer model

1. **Image defaults:** `openclaw.defaults.json.tmpl` + `seed/`
2. **Runtime env/secrets:** `.env` + host env variables
3. **Persistent volume:** `${OPENCLAW_STATE_DIR}` mounted to `/home/node/.openclaw`
4. **Init logic:** `entrypoint-init.sh` copies only missing files; never overwrites existing

## Notes

- Keep secrets out of git/image.
- Pin image tags for reproducibility.
- Tailscale remains host-level.
