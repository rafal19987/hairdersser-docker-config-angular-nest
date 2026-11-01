#!/usr/bin/env bash
# Test environment: bash scripts/test-env.sh <up|reset|down|status|logs [service]>
set -euo pipefail

cd "$(dirname "$0")/.."

TEST=(docker compose -f docker-compose.test.yaml)

wait_for_seed() {
  echo "Waiting for migrations and test data..."
  "${TEST[@]}" up --build --exit-code-from seed seed 2>&1 | grep --line-buffered 'seed-1' | sed 's/^.*seed-1 *| //'
}

print_info() {
  cat <<'EOF'

Test environment is ready:
  Admin panel   http://localhost         admin@test.local / Admin1234!
  Reception     recepcja@demo.hairdresser.pl / Pracownik1234!
  Employees     anna.nowak@demo.hairdresser.pl (and others) / Pracownik1234!
  Website       http://localhost:3001    clients: ewa.kowalska@example.com / Klient1234!
  API           http://localhost:3000/api/docs
  Mailbox       http://localhost:8025    (every mail the backend sends)
  Database      localhost:3307           test / test, database hairdresser_test
EOF
}

case "${1:-}" in
  up)
    # The dev stack uses the same ports; stopping it keeps its data
    docker compose stop >/dev/null 2>&1 || true
    "${TEST[@]}" up -d --build mysql mailpit backend frontend landing
    wait_for_seed
    print_info
    ;;
  reset)
    # The database lives in memory, so recreating it wipes all data
    "${TEST[@]}" up -d --force-recreate mysql mailpit
    "${TEST[@]}" up -d --force-recreate --no-deps backend
    wait_for_seed
    print_info
    ;;
  down)
    "${TEST[@]}" down
    ;;
  status)
    "${TEST[@]}" ps
    ;;
  logs)
    "${TEST[@]}" logs --tail=100 "${2:-backend}"
    ;;
  *)
    echo "Usage: bash scripts/test-env.sh <up|reset|down|status|logs [service]>"
    exit 1
    ;;
esac
