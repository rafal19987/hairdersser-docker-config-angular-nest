#!/usr/bin/env bash
# Pulls the latest images and restarts the staging stack. Runs as the deploy user:
#   - from GitHub Actions, as the only command its SSH key may run; the workflow passes
#     "<user> <token>" on stdin so Docker can pull images from ghcr.io
#   - by hand: sudo -u deploy /opt/hairdresser/repo/deploy/staging/deploy.sh
#
# Wrapped in main() so bash reads the whole script before `git reset` replaces it on disk.

set -euo pipefail

main() {
  local root=/opt/hairdresser
  cd "$root/repo"

  git fetch --quiet origin master
  git reset --quiet --hard origin/master

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

  local compose=(docker compose -f deploy/staging/docker-compose.yaml --env-file "$root/.env")
  "${compose[@]}" pull --quiet
  "${compose[@]}" up --detach --remove-orphans --wait --wait-timeout 300
  "${compose[@]}" run --rm seed
  docker image prune --force > /dev/null

  echo "Deployed $(git rev-parse --short HEAD)"
}

main "$@"
exit
