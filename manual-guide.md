# VPS + OpenClaw (Docker) Guide

This is a two-part setup, aligned to your current security model:

1. **Host hardening + Tailscale** (host-level)
2. **OpenClaw container runtime** (Docker-level)

> Key architecture decision: **Tailscale runs on the host**. OpenClaw runs in Docker.

---

## One-command full setup

```bash
sudo ./setup.sh all --admin-user openclaw -- --workspace-dir-name workspace
```

`all` mode runs in two privilege phases:
- root phase: Linux hardening + Docker engine install
- user phase (`--admin-user`): Docker bootstrap (`prepare-env`, `build`, `up`, `logs`)

If `all` mode starts from a root-only path (like `/root/...`), it auto-relocates the repo to `/home/<admin-user>/repos/<repo-name>` before the user-phase Docker bootstrap continues.

---

## Part 1 — Linux host setup (Ubuntu/Debian)

## Goal
- Non-root admin user
- SSH key-only auth
- Root login disabled
- Password auth disabled
- Firewall deny-by-default
- Tailscale-only remote access path

## Files provided
- Script: `./linux/bootstrap-linux-tailscale.sh`
- Root helper: `./setup.sh linux` (passes args through to the script above)

## What the script does
- Validates root privileges
- Creates/updates admin user (default: `openclaw`)
- Copies `/root/.ssh/authorized_keys` to new admin user (optional)
- Hardens SSH (`PermitRootLogin no`, `PasswordAuthentication no`, key-only)
- Enables UFW deny-by-default
- Allows SSH only via `tailscale0` interface
- Optionally allows UDP 41641 (DERP/direct path compatibility)
- Enables unattended security updates

## Run it

```bash
sudo ./setup.sh linux \
  --admin-user openclaw \
  --copy-root-authorized-keys yes \
  --allow-udp-41641 yes \
  --tailscale-up ssh \
  --run-upgrade yes \
  --set-password prompt
```

## Flags
- `--admin-user <name>` (default: `openclaw`)
- `--copy-root-authorized-keys yes|no` (default: `yes`)
- `--allow-udp-41641 yes|no` (default: `yes`)
- `--tailscale-up ssh|basic|no` (default: `ssh`)
- `--run-upgrade yes|no` (default: `yes`)
- `--set-password prompt|skip` (default: `prompt`)

> The script now launches `tailscale up` (default `--ssh`) at the end and prints a hard warning: **do not reboot or close provider console until Tailscale auth + SSH verification succeed**.

## Post-checks

```bash
sudo sshd -t
sudo systemctl status ssh || sudo systemctl status sshd
sudo ufw status verbose
tailscale status
```

Then verify from your laptop:

```bash
ssh openclaw@<tailscale-ip-or-magicdns>
sudo whoami
```

---

## Part 2 — Dockerized OpenClaw setup

## Goal
- Persistent OpenClaw state on host (`~/.openclaw`)
- Gateway container with restart policy
- No public internet exposure required
- Reachable over Tailscale host network path

## Files provided
- Dockerfile: `./docker/Dockerfile.openclaw`
- Root helper: `./setup.sh docker`

## If you run Part 1 and Part 2 separately

After Linux setup, switch to the admin user before Docker bootstrap:

```bash
sudo usermod -aG docker openclaw
sudo install -d -m 755 -o openclaw -g openclaw /home/openclaw/repos
sudo rsync -a --chown=openclaw:openclaw /root/openclaw-secure-vps/ /home/openclaw/repos/openclaw-secure-vps/
sudo -iu openclaw
cd /home/openclaw/repos/openclaw-secure-vps
./setup.sh docker --state-user openclaw --workspace-dir-name workspace
```

Notes:
- Use a fresh login shell (`sudo -iu openclaw`) so `docker` group membership is active.
- Run Docker bootstrap from a user-readable path (for example `/home/openclaw/repos/...`), not `/root/...`.

## Recommended runtime (use official image)

Prefer pinned official image tags in production-like use:

```bash
docker pull ghcr.io/openclaw/openclaw:latest
```

Then run with a host bind mount for persistence:

```bash
docker run -d \
  --name openclaw-gateway \
  --restart unless-stopped \
  -p 127.0.0.1:18789:18789 \
  -v /home/openclaw/.openclaw:/home/node/.openclaw \
  ghcr.io/openclaw/openclaw:latest
```

> Binding to `127.0.0.1` keeps gateway local to host. You can access through Tailscale SSH/tunnel.

## Alternative: build your own wrapper image

```bash
docker build -f ./docker/Dockerfile.openclaw -t openclaw-custom:local ./docker
```

Then run:

```bash
docker run -d \
  --name openclaw-gateway \
  --restart unless-stopped \
  -p 127.0.0.1:18789:18789 \
  -v /home/openclaw/.openclaw:/home/node/.openclaw \
  openclaw-custom:local
```

## Validate

```bash
docker ps
docker logs --tail=100 openclaw-gateway
```

If needed:

```bash
docker exec -it openclaw-gateway openclaw status
```

---

## Operations playbook

## Upgrade

```bash
docker pull ghcr.io/openclaw/openclaw:latest
docker stop openclaw-gateway
docker rm openclaw-gateway
# run again with same volume mapping
```

## Backup
Backup host-mounted state:

- `/home/openclaw/.openclaw/openclaw.json`
- `/home/openclaw/.openclaw/workspace/`
- `/home/openclaw/.openclaw/agents/` (sessions/state)

## Security notes
- Keep SSH open only on `tailscale0`
- Keep OpenClaw gateway bound to loopback unless you intentionally expose it
- Use pinned image versions for reproducibility
- Prefer explicit allowlists in OpenClaw channel config

---

## Optional docker-compose (quick template)

```yaml
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw-gateway
    restart: unless-stopped
    ports:
      - "127.0.0.1:18789:18789"
    volumes:
      - /home/openclaw/.openclaw:/home/node/.openclaw
```

Run:

```bash
docker compose up -d
```

---

## Practical recommendation for your current pattern

- Keep your host model exactly as-is (Tailscale + strict firewall)
- Move only OpenClaw process management into Docker
- Keep persistent state on host-mounted volume
- Keep everything private to tailnet
