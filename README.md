# OpenClaw Secure VPS Setup (`openclaw-secure-vps`)

This is a **reusable bootstrap kit** for bringing a fresh VPS to a secure, Dockerized OpenClaw setup with minimal manual steps.

It is designed for a **Tailscale-first security model**:
- Tailscale runs on the host ([tailscale.com](https://tailscale.com))
- SSH is hardened and restricted
- OpenClaw runs in Docker with persistent host-mounted state

---

## What this bundle does

At a high level, it gives you two tracks:

1. **Host setup (Linux hardening + access path)**
   - creates/administers a non-root Linux user
   - hardens SSH (no root login, no password auth)
   - configures host firewall policy (UFW)
   - installs/boots Tailscale and guides auth flow

2. **Container setup (OpenClaw runtime)**
   - installs Docker + Compose
   - builds/starts an OpenClaw container stack
   - creates `.env` from `.env.example`
   - seeds baseline workspace/config defaults (non-destructive)

---

## Why this exists

- Avoid repeating manual VPS setup every time
- Keep setup consistent across multiple OpenClaw instances
- Separate stable bootstrap logic from instance-specific secrets
- Prepare for future CLI wizard automation (modular step scripts)

---

## Folder layout

- `manual-guide.md` — full manual walkthrough (Linux + Docker)
- `linux/bootstrap-linux-tailscale.sh` — host bootstrap script
- `docker/Dockerfile.openclaw` — lightweight wrapper image
- `docker/bootstrap/` — modular Docker bootstrap stack
  - `scripts/10-install-docker.sh`
  - `scripts/20-prepare-env.sh`
  - `scripts/30-build-image.sh`
  - `scripts/40-up.sh`
  - `scripts/50-logs.sh`
  - `scripts/setup-docker-openclaw.sh` (orchestrator)

---

## Quick start

Clone this setup bundle first (recommended repo: `openclaw-secure-vps`):

```bash
git clone https://github.com/haukurmar/openclaw-secure-vps.git ~/openclaw-secure-vps
cd ~/openclaw-secure-vps/docs/vps-openclaw-setup
```

## Setup

```bash
# Linux setup only
sudo ./setup.sh linux

# Docker setup only
sudo ./setup.sh docker

# Run both (linux first, then docker)
sudo ./setup.sh all

# Run both with separate flags (left of -- => linux, right => docker)
sudo ./setup.sh all --admin-user openclaw --tailscale-up ssh -- --workspace-dir-name workspace-main
```

✅ And you're done with setup.

The sections below are quick-reference options for Linux and Docker modes when you want to customize behavior.

---

### Linux mode options

(Forwarded to `linux/bootstrap-linux-tailscale.sh` via `./setup.sh linux ...`)

| Flag | Default | What it does |
|---|---|---|
| `--admin-user <name>` | `openclaw` | Linux admin username to create/manage and allow in SSH config. |
| `--copy-root-authorized-keys yes\|no` | `yes` | Copies `/root/.ssh/authorized_keys` to the admin user. |
| `--allow-udp-41641 yes\|no` | `yes` | Opens UDP 41641 in UFW (optional Tailscale direct path compatibility). |
| `--tailscale-up ssh\|basic\|no` | `ssh` | Runs `tailscale up --ssh`, `tailscale up`, or skips it. |
| `--run-upgrade yes\|no` | `yes` | Runs `apt upgrade -y` + `apt autoremove -y` after `apt update`. |

Example with explicit Linux values:

```bash
sudo ./setup.sh linux \
  --admin-user openclaw \
  --copy-root-authorized-keys yes \
  --allow-udp-41641 yes \
  --tailscale-up ssh \
  --run-upgrade yes
```

---

### Docker mode options

Run Docker setup:

```bash
sudo ./setup.sh docker
```

(Forwarded to `docker/bootstrap/scripts/setup-docker-openclaw.sh`.)

| Flag | Default | What it does |
|---|---|---|
| `--workspace-dir-name <name>` | `workspace` | Sets OpenClaw workspace folder under state dir (e.g. `workspace-main`). |

Example custom workspace name:

```bash
sudo ./setup.sh docker --workspace-dir-name workspace-main
```

---

## Notes

- `.env` is auto-created from `.env.example` if missing.
- Secrets/tokens should be supplied via runtime env or secure secret handling, not baked into images.
- Current memory seed is intentionally minimal/agnostic; richer memory profile can be plugged in later.
