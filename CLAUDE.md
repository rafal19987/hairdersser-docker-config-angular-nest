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

# End-to-end tests

`e2e/` holds Playwright tests that run across the website, the admin panel and Mailpit against the test environment.

```bash
cd e2e && npm install                          # first time only; uses the installed Chrome
PLAYWRIGHT_HTML_OPEN=never npx playwright test
npx playwright test --headed                   # watch it in a browser window
```

Each run creates its own client with a unique email, so it doesn't need a reset first.

# Staging server

`deploy/staging/` holds the stack of the public test server and the scripts that set it up. The user runs commands on
the server; Claude prepares them and doesn't log in there.

- The `Deploy staging` workflow builds the images from the submodule pointers on `master`, pushes them to
  `ghcr.io/rafal19987/hairdresser-{backend,admin,website}` and runs `deploy.sh` on the server over SSH. It starts after
  every submodule update, after a change in `deploy/staging/`, and by hand.
- Secrets live only on the server in `/opt/hairdresser/.env`; GitHub holds the domain, the host and the deploy key.
- Website at `https://<domain>`, admin at `https://admin.<domain>`, API at `https://api.<domain>`. Portainer
  (`127.0.0.1:9443`) and Mailpit (`127.0.0.1:8025`) are reachable only through an SSH tunnel.

# Branches and pull requests

`master` and `develop` are protected by GitHub rulesets: a direct push is rejected, every change goes through a pull
request.

| Repository | Branch from | Pull request into |
| --- | --- | --- |
| `backend`, `frontend`, `landing-page` | `develop` | `develop` |
| root (this repository) | `master` | `master` |

- Name branches by kind: `feature/…`, `fix/…`, `chore/…`, `ci/…`, `docs/…`.
- Right after pushing a branch, open its pull request with `gh pr create --base <develop|master> --head <branch>` and
  give the user its link. Never merge pull requests; the user reviews and merges them.
- Title: the first line of the commit message. Body: what changed and why, how it was tested, and what must be merged
  first. End the body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- A change spanning several repositories gets one pull request per repository; list them all with their merge order.
- Open a release pull request `develop` → `master` in an app only when the user asks for it; it must be merged with a
  merge commit, not squashed, so the two branches keep a shared history.
- Don't commit submodule pointers in the root repository: after a merge to `develop`, the `Update submodules`
  workflow opens and merges a pull request with the new pointers.
- If `gh` isn't available, give the user the compare link GitHub prints on push
  (`https://github.com/<owner>/<repo>/pull/new/<branch>`) instead.
