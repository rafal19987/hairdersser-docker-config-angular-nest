#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 staging server. Run as root; running it again is safe.
#   bash setup-server.sh [domain]     the domain defaults to <public IP>.sslip.io
#
# Installs Docker, a firewall (22, 80, 443), fail2ban, automatic security updates and swap,
# creates the deploy user with an SSH key that may only run deploy.sh, clones this repository
# to /opt/hairdresser/repo and writes /opt/hairdresser/.env with random secrets.

set -euo pipefail

REPO_URL=https://github.com/rafal19987/hairdersser-docker-config-angular-nest.git
ROOT=/opt/hairdresser

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root" >&2
  exit 1
fi

public_ip=$(curl -fsS4 https://api.ipify.org)
domain=${1:-${public_ip//./-}.sslip.io}

echo "==> System packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -yq
apt-get install -yq ca-certificates curl git openssl ufw fail2ban unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now fail2ban

echo "==> Swap"
if [ -z "$(swapon --show)" ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile > /dev/null
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Docker"
if ! command -v docker > /dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
# Without a limit container logs grow until the disk is full
cat > /etc/docker/daemon.json <<'EOF'
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
EOF
systemctl restart docker

echo "==> Firewall"
ufw allow OpenSSH > /dev/null
ufw allow 80/tcp > /dev/null
ufw allow 443/tcp > /dev/null
ufw allow 443/udp > /dev/null
ufw --force enable > /dev/null

echo "==> Deploy user and repository"
id deploy > /dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy
mkdir -p "$ROOT"
[ -d "$ROOT/repo/.git" ] || git clone --quiet "$REPO_URL" "$ROOT/repo"

admin_password=""
if [ ! -f "$ROOT/.env" ]; then
  admin_password="$(openssl rand -hex 12)Aa1!"
  sed -e "s|^DOMAIN=.*|DOMAIN=$domain|" \
    -e "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=$(openssl rand -hex 24)|" \
    -e "s|^MYSQL_PASSWORD=.*|MYSQL_PASSWORD=$(openssl rand -hex 24)|" \
    -e "s|^JWT_ACCESS_TOKEN_SECRET_KEY=.*|JWT_ACCESS_TOKEN_SECRET_KEY=$(openssl rand -hex 32)|" \
    -e "s|^JWT_REFRESH_TOKEN_SECRET_KEY=.*|JWT_REFRESH_TOKEN_SECRET_KEY=$(openssl rand -hex 32)|" \
    -e "s|^JWT_CLIENT_ACCESS_TOKEN_SECRET_KEY=.*|JWT_CLIENT_ACCESS_TOKEN_SECRET_KEY=$(openssl rand -hex 32)|" \
    -e "s|^SEED_ADMIN_PASSWORD=.*|SEED_ADMIN_PASSWORD=$admin_password|" \
    "$ROOT/repo/deploy/staging/.env.example" > "$ROOT/.env"
  chmod 600 "$ROOT/.env"
fi
chown -R deploy:deploy "$ROOT"

# The GitHub Actions key may run deploy.sh and nothing else
ci_key=""
authorized_keys=/home/deploy/.ssh/authorized_keys
if ! grep -q hairdresser-ci "$authorized_keys" 2> /dev/null; then
  tmp=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N '' -C hairdresser-ci -f "$tmp/key"
  install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
  echo "restrict,command=\"$ROOT/repo/deploy/staging/deploy.sh\" $(cat "$tmp/key.pub")" >> "$authorized_keys"
  chown deploy:deploy "$authorized_keys"
  chmod 600 "$authorized_keys"
  ci_key=$(cat "$tmp/key")
  rm -rf "$tmp"
fi

cat <<EOF

==========================================================================
Server ready.

  Website      https://$domain
  Admin panel  https://admin.$domain
  API          https://api.$domain/api/docs

GitHub, root repository → Settings → Secrets and variables → Actions
(repository variables and secrets, the build job does not see environment ones)

  Variable  STAGING_DOMAIN           $domain
  Variable  STAGING_HOST             $public_ip
  Secret    STAGING_SSH_KNOWN_HOSTS  $public_ip $(cut -d' ' -f1,2 /etc/ssh/ssh_host_ed25519_key.pub)
EOF

if [ -n "$ci_key" ]; then
  cat <<EOF
  Secret    STAGING_SSH_KEY          the whole key below, from -----BEGIN to END----- inclusive:

$ci_key

It is shown only this once and is not kept on the server.
EOF
fi

if [ -n "$admin_password" ]; then
  cat <<EOF

Admin panel login: $(grep '^SEED_ADMIN_EMAIL=' "$ROOT/.env" | cut -d= -f2) / $admin_password
(also in $ROOT/.env)
EOF
fi

echo "=========================================================================="
