#!/usr/bin/env bash
# Pulls the latest images and restarts the staging stack. Runs as the deploy user:
#   - from GitHub Actions, as the only command its SSH key may run; the workflow passes
#     "<user> <token>" on stdin so Docker can pull images from ghcr.io
#   - by hand: sudo -u deploy /opt/hairdresser/repo/deploy/staging/deploy.sh
#
# After `git reset` the script starts again from the updated file, so a change to it applies to the
# same deploy. main() is called together with exit on the last line, so bash has read the whole
# script before the reset replaces it on disk.

set -euo pipefail

# Caddy asks for this login on https://api.<domain>/api/docs; the password stays in .env next to the hash
ensure_docs_login() {
  local env_file=$1 password hash
  grep -q '^DOCS_PASSWORD_HASH=' "$env_file" && return

  password=$(openssl rand -hex 12)
  hash=$(docker run --rm caddy:2.10 caddy hash-password --plaintext "$password")
  # Single quotes keep Docker Compose from reading the $ signs of the hash as variables
  printf "\n# API docs login, added by deploy.sh\nDOCS_USER=docs\nDOCS_PASSWORD=%s\nDOCS_PASSWORD_HASH='%s'\n" \
    "$password" "$hash" >> "$env_file"
}

main() {
  local root=/opt/hairdresser
  cd "$root/repo"

  if [ "${1:-}" != --updated ]; then
    git fetch --quiet origin master
    git reset --quiet --hard origin/master
    exec "$root/repo/deploy/staging/deploy.sh" --updated
  fi

  # Registry login lives in a temporary config, so no token stays on the server
  DOCKER_CONFIG=$(mktemp -d)
  export DOCKER_CONFIG
  trap 'rm -rf "$DOCKER_CONFIG"' EXIT

  if [ ! -t 0 ]; then
    local user token
    if read -r user token && [ -n "${token:-}" ]; then
      docker login ghcr.io --username "$user" --password-stdin <<< "$token" > /dev/null
    fi
  fi

  ensure_docs_login "$root/.env"

  local compose=(docker compose -f deploy/staging/docker-compose.yaml --env-file "$root/.env")
  "${compose[@]}" pull --quiet
  "${compose[@]}" up --detach --remove-orphans --wait --wait-timeout 300
  # A Caddyfile change alone does not recreate the container
  "${compose[@]}" exec -T caddy caddy reload --config /etc/caddy/site/Caddyfile --adapter caddyfile
  "${compose[@]}" run --rm seed
  docker image prune --force > /dev/null

  echo "Deployed $(git rev-parse --short HEAD)"
}

main "$@"; exit
