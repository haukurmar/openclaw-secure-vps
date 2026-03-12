#!/usr/bin/env bash
set -euo pipefail

ADMIN_USER="openclaw"
COPY_ROOT_KEYS="yes"
ALLOW_UDP_41641="yes"
TAILSCALE_UP_MODE="ssh"  # ssh|basic|no
RUN_UPGRADE="yes"        # yes|no
SET_PASSWORD="prompt"     # prompt|skip

while [[ $# -gt 0 ]]; do
  case "$1" in
    --admin-user)
      ADMIN_USER="$2"; shift 2 ;;
    --copy-root-authorized-keys)
      COPY_ROOT_KEYS="$2"; shift 2 ;;
    --allow-udp-41641)
      ALLOW_UDP_41641="$2"; shift 2 ;;
    --tailscale-up)
      TAILSCALE_UP_MODE="$2"; shift 2 ;;
    --run-upgrade)
      RUN_UPGRADE="$2"; shift 2 ;;
    --set-password)
      SET_PASSWORD="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if [[ "$TAILSCALE_UP_MODE" != "ssh" && "$TAILSCALE_UP_MODE" != "basic" && "$TAILSCALE_UP_MODE" != "no" ]]; then
  echo "Invalid --tailscale-up value: $TAILSCALE_UP_MODE (expected: ssh|basic|no)" >&2
  exit 1
fi
if [[ "$RUN_UPGRADE" != "yes" && "$RUN_UPGRADE" != "no" ]]; then
  echo "Invalid --run-upgrade value: $RUN_UPGRADE (expected: yes|no)" >&2
  exit 1
fi
if [[ "$SET_PASSWORD" != "prompt" && "$SET_PASSWORD" != "skip" ]]; then
  echo "Invalid --set-password value: $SET_PASSWORD (expected: prompt|skip)" >&2
  exit 1
fi

echo "==> Updating package metadata"
apt update -y

if [[ "$RUN_UPGRADE" == "yes" ]]; then
  echo "==> Upgrading installed packages"
  apt upgrade -y
  apt autoremove -y
else
  echo "==> Skipping package upgrade (--run-upgrade no)"
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "==> Installing ufw"
  apt install -y ufw
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "==> Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! id -u "$ADMIN_USER" >/dev/null 2>&1; then
  echo "==> Creating admin user: $ADMIN_USER"
  adduser --disabled-password --gecos "" "$ADMIN_USER"
fi

usermod -aG sudo "$ADMIN_USER"

if [[ "$COPY_ROOT_KEYS" == "yes" ]]; then
  if [[ -f /root/.ssh/authorized_keys ]]; then
    echo "==> Copying root authorized_keys to $ADMIN_USER"
    install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
    cp /root/.ssh/authorized_keys "/home/$ADMIN_USER/.ssh/authorized_keys"
    chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
    chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
  else
    echo "WARN: /root/.ssh/authorized_keys not found; skipping key copy"
  fi
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_PATH="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
cp "$SSHD_CONFIG" "$BACKUP_PATH"
echo "==> Backed up sshd config to $BACKUP_PATH"

ensure_sshd_key() {
  local key="$1"
  local value="$2"
  if grep -qiE "^\s*${key}\s+" "$SSHD_CONFIG"; then
    sed -i -E "s|^\s*#?\s*${key}\s+.*|${key} ${value}|I" "$SSHD_CONFIG"
  else
    echo "${key} ${value}" >> "$SSHD_CONFIG"
  fi
}

ensure_sshd_key "PermitRootLogin" "no"
ensure_sshd_key "PasswordAuthentication" "no"
ensure_sshd_key "PubkeyAuthentication" "yes"
ensure_sshd_key "ChallengeResponseAuthentication" "no"
ensure_sshd_key "KbdInteractiveAuthentication" "no"
ensure_sshd_key "UsePAM" "yes"
ensure_sshd_key "AllowUsers" "$ADMIN_USER"

if command -v sshd >/dev/null 2>&1; then
  # Some minimal cloud images are missing this runtime dir until ssh starts.
  mkdir -p /run/sshd
  chmod 755 /run/sshd

  echo "==> Validating sshd config"
  sshd -t
fi

echo "==> Restarting SSH service"
systemctl restart ssh || systemctl restart sshd

# UFW hardening: deny all inbound, allow outbound, allow SSH only on tailscale0
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH only over tailscale interface
ufw allow in on tailscale0 to any port 22 proto tcp

# Optional explicit tailscale UDP port
if [[ "$ALLOW_UDP_41641" == "yes" ]]; then
  ufw allow 41641/udp
fi

ufw --force enable

# Enable unattended security updates
apt install -y unattended-upgrades apt-listchanges

dpkg-reconfigure -f noninteractive unattended-upgrades || true

echo

echo "============================================================"
echo "Host hardening complete."
echo "============================================================"
echo

echo "IMPORTANT: SSH is now restricted to tailscale0."
echo "Do NOT reboot or close your provider console until Tailscale auth is completed and verified."
echo

case "$TAILSCALE_UP_MODE" in
  ssh)
    echo "==> Launching: tailscale up --ssh"
    echo "    Follow the auth URL/login flow now if prompted."
    tailscale up --ssh
    ;;
  basic)
    echo "==> Launching: tailscale up"
    echo "    Follow the auth URL/login flow now if prompted."
    tailscale up
    ;;
  no)
    echo "==> Skipping tailscale up (per --tailscale-up no)"
    ;;
esac

echo

echo "Next required verification steps:"
echo "  1) tailscale status"
echo "  2) sudo ufw status verbose"
echo "  3) From your local machine: ssh $ADMIN_USER@<tailscale-ip-or-magicdns>"
echo "  4) After login: sudo whoami   # should print root"
echo

echo "Only after all checks pass should you reboot or close the provider console session."

echo
if [[ "$SET_PASSWORD" == "prompt" ]]; then
  echo "==> Final step: set password for user '$ADMIN_USER'"
  echo "    (needed for sudo prompts unless you use passwordless sudo policy)"
  passwd "$ADMIN_USER"
else
  echo "==> Skipping password set (--set-password skip)"
fi
