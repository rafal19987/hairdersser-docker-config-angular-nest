# 💈 Hairdresser Management System

An admin panel for managing a hairdressing salon — users, roles, permissions, services, and appointment calendar — plus the public salon website with online booking.

## Project Structure

```
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── src/
├── backend/
│   ├── Dockerfile
│   └── src/
├── landing-page/        # public website: Next.js + Sanity CMS
│   ├── Dockerfile
│   └── src/
├── docker-compose.yaml
├── .env
└── .env.example
```

## Running with Docker (recommended)

### 1. Clone the repository with its submodules

`backend`, `frontend` and `landing-page` are git submodules tracking their `develop` branches:

```bash
git clone --recurse-submodules https://github.com/rafal19987/hairdersser-docker-config-angular-nest.git hairdresser
cd hairdresser
```

Already cloned without submodules? Run `git submodule update --init`.

### 2. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and fill in the values:

```env
# MySQL
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_DATABASE=hairdresser
MYSQL_USERNAME=hairdresser_user
MYSQL_PASSWORD=your_password
MYSQL_PORT=3306

# Backend
NODE_ENV=production
PORT=3000
JWT_ACCESS_TOKEN_SECRET_KEY=random-long-string
JWT_REFRESH_TOKEN_SECRET_KEY=another-random-long-string
JWT_ACCESS_TOKEN_EXPIRES_IN=10h
JWT_REFRESH_TOKEN_EXPIRES_IN=7d
MAILTRAP_API_KEY=your_mailtrap_key
MAILTRAP_USE_SANDBOX=true
MAILTRAP_INBOX_ID=your_inbox_id
MAIL_FROM=noreply@hairdresser.pl

# CORS — frontend address (where requests come from)
APP_URL=http://localhost

# Frontend
API_URL=http://localhost:3000
FRONTEND_PORT=80

# Public website (landing-page) — Sanity project settings are needed at build time
LANDING_URL=http://localhost:3001
LANDING_PORT=3001
NEXT_PUBLIC_SANITY_PROJECT_ID=your_sanity_project_id
NEXT_PUBLIC_SANITY_DATASET=production

# Seed — initial admin credentials
SEED_ADMIN_EMAIL=admin@hairdresser.pl
SEED_ADMIN_PASSWORD=Admin1234!
```

### 3. Build and start

```bash
docker compose up --build -d
```

### 4. Check status

```bash
docker compose ps
```

All services should have status `running`, except `seed` which shows `exited (0)` — this is correct, the seeder runs once and exits.

### 5. Open the application

| Service     | Address                        |
| ----------- | ------------------------------ |
| Frontend    | http://localhost               |
| Website     | http://localhost:3001          |
| Sanity CMS  | http://localhost:3001/cms      |
| Backend API | http://localhost:3000/api      |
| Swagger     | http://localhost:3000/api/docs |

### 6. Log in

Default admin credentials (created by the seeder):

```
Email:    admin@hairdresser.pl
Password: Admin1234!
```

> Change the password after the first login.

---

## Useful Docker Commands

```bash
# Logs for all services
docker compose logs -f

# Logs for a specific service
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f seed

# Rebuild and restart a single service (e.g. after a backend code change)
docker compose up --build -d backend

# Stop containers (database data is preserved)
docker compose down

# Stop containers and reset the database
docker compose down -v

# Manually re-run the seeder (e.g. after docker compose down -v)
docker compose run --rm seed
```

---

## Local Development (without Docker)

### Backend

```bash
cd backend
cp .env.example .env
npm install
npm run start:dev
```

Backend available at: http://localhost:3000/api/docs

### Frontend

```bash
cd frontend
npm install
npm run start
```

Frontend available at: http://localhost:4200

> In dev mode the frontend communicates with the backend via `http://localhost:3000` (configured in `src/environments/environment.ts`).

### Website (landing-page)

```bash
cd landing-page
cp .env.example .env.local   # fill in the Sanity project id and dataset
npm install
npm run dev
```

Website available at: http://localhost:3001, Sanity Studio at http://localhost:3001/cms

---

## Environment Variables Reference

### Backend

| Variable                       | Description                | Example                              |
| ------------------------------ | -------------------------- | ------------------------------------ |
| `NODE_ENV`                     | Runtime environment        | `production` / `development`         |
| `PORT`                         | Backend port               | `3000`                               |
| `MYSQL_HOST`                   | Database host              | `mysql` (Docker) / `localhost` (dev) |
| `MYSQL_PORT`                   | Database port              | `3306`                               |
| `MYSQL_DATABASE`               | Database name              | `hairdresser`                        |
| `MYSQL_USERNAME`               | Database user              | `hairdresser_user`                   |
| `MYSQL_PASSWORD`               | Database password          | —                                    |
| `MYSQL_SYNCHRONIZE`            | Auto-sync schema           | `false` (prod) / `true` (dev)        |
| `JWT_ACCESS_TOKEN_SECRET_KEY`  | JWT access token secret    | random string                        |
| `JWT_REFRESH_TOKEN_SECRET_KEY` | JWT refresh token secret   | different random string              |
| `JWT_ACCESS_TOKEN_EXPIRES_IN`  | Access token expiry        | `10h`                                |
| `JWT_REFRESH_TOKEN_EXPIRES_IN` | Refresh token expiry       | `7d`                                 |
| `MAILTRAP_API_KEY`             | Mailtrap API key           | —                                    |
| `MAILTRAP_USE_SANDBOX`         | Use Mailtrap sandbox (dev) | `true` / `false`                     |
| `MAILTRAP_INBOX_ID`            | Mailtrap sandbox inbox ID  | —                                    |
| `MAIL_FROM`                    | Sender email address       | `noreply@hairdresser.pl`             |
| `APP_URL`                      | Frontend address (CORS)    | `http://localhost`                   |

### Frontend (build-time)

| Variable        | Description     | Example                 |
| --------------- | --------------- | ----------------------- |
| `API_URL`       | Backend address | `http://localhost:3000` |
| `FRONTEND_PORT` | Frontend port   | `80`                    |

### Website (build-time)

| Variable                        | Description                       | Example                 |
| ------------------------------- | --------------------------------- | ----------------------- |
| `LANDING_URL`                   | Public address of the website     | `http://localhost:3001` |
| `LANDING_PORT`                  | Website port                      | `3001`                  |
| `NEXT_PUBLIC_SANITY_PROJECT_ID` | Sanity project id                 | —                       |
| `NEXT_PUBLIC_SANITY_DATASET`    | Sanity dataset                    | `production`            |

### Seed

| Variable              | Description            | Example                |
| --------------------- | ---------------------- | ---------------------- |
| `SEED_ADMIN_EMAIL`    | Initial admin email    | `admin@hairdresser.pl` |
| `SEED_ADMIN_PASSWORD` | Initial admin password | `Admin1234!`           |

---

## System Architecture

### Authentication Flow

1. Admin creates a user in the panel
2. System generates an `invitationToken` and sends a link to the user's email
3. User sets their password via the link (valid for 48h)
4. Login via JWT — access token (10h) + refresh token (7d)
5. Deactivating an account removes all associated refresh tokens

### Roles & Permissions

Role-based access control with granular permission management.

Available resources: `users`, `roles`, `services`, `calendar`, `clients`, `settings`, `audit-logs`

Available actions: `none`, `create`, `read`, `write`, `delete`, `all`, `admin`

---

## Troubleshooting

**Backend cannot connect to the database**

```bash
docker compose logs mysql
docker compose logs backend
```

Make sure `MYSQL_HOST=mysql` in docker compose (the service name, not `localhost`).

**CORS error**
Check that `APP_URL` in `.env` matches the frontend address in the browser (e.g. `http://localhost`).

**Seeder failed**

```bash
docker compose logs seed
# Re-run after fixing the issue:
docker compose run --rm seed
```

**Frontend shows stale code after rebuild**

```bash
docker compose up --build -d frontend
```

**Full environment reset**

```bash
docker compose down -v   # also removes volumes (deletes database data!)
docker compose up --build -d
```
