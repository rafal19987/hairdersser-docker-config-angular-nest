@AGENTS.md

# Test environment

A separate Docker stack for clicking through the apps. Every value in `docker-compose.test.yaml`
is a throwaway test value, so testing never needs the real `.env`.

```bash
bash scripts/test-env.sh up       # build and start; stops the dev stack (same ports), its data stays
bash scripts/test-env.sh reset    # fresh database and empty mailbox
bash scripts/test-env.sh down     # stop; back to development with `docker compose up -d`
bash scripts/test-env.sh logs backend
```

| What | Address | Account |
| --- | --- | --- |
| Admin panel | http://localhost (built) or http://localhost:4200 (`cd frontend && npx ng serve`) | `admin@test.local` / `Admin1234!` |
| Reception (sees every calendar) | admin panel | `recepcja@demo.hairdresser.pl` / `Pracownik1234!` |
| Employees | admin panel | `anna.nowak@demo.hairdresser.pl`, `tomasz.wisniewski@demo.hairdresser.pl`, `katarzyna.zielinska@demo.hairdresser.pl` / `Pracownik1234!` |
| Website | http://localhost:3001 | clients `ewa.kowalska@example.com`, `marek.lis@example.com` / `Klient1234!` |
| Mailbox (Mailpit) | http://localhost:8025 | every mail the backend sends |
| API docs | http://localhost:3000/api/docs | |
| Database | localhost:3307 | `test` / `test`, database `hairdresser_test` |

- The database lives in memory; `reset` recreates it and the seed adds demo data dated from that day.
- The salon is closed on Sundays, so pick a weekday when booking.
- Request limits are off (`RATE_LIMIT_ENABLED=false`) and CORS allows the built admin, `ng serve` and the website.
- Admin routes live under `/dashboard`, e.g. `/dashboard/calendar`.

# Browser testing

- Use the `playwright-cli` skill. Settings are in `.playwright/cli.config.json`: Chrome, `pl-PL`, `Europe/Warsaw`,
  1440×900, headless. Add `--headed` to `open` when the user wants to watch.
- Target elements by role (`getByRole('button', { name: 'Zaloguj' })`) or by refs from the snapshot; use `find` instead
  of reading whole snapshots.
- Read mails through the Mailpit API instead of the database: `GET http://localhost:8025/api/v1/messages`, then
  `GET /api/v1/message/<ID>`, whose `HTML` field holds activation, reset and manage links.
- Data created while testing disappears with `reset`; outputs go to `.playwright-cli/`, which git ignores.
