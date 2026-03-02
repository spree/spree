# Spree Server

A Rails application that mounts the Spree gems (core, api, admin, emails) from the `spree/` directory and serves the API and admin interface.

## Structure

```
server/
├── Gemfile              # References gems via path: ../spree
├── Dockerfile           # Multi-stage build for Docker
├── config/
└── db/
```

## Setup

### Local Development (Ruby developers)

PostgreSQL and Redis must be running before you start. If you have them installed locally, make sure they're running. Otherwise you can start them with Docker:

```bash
docker run -d --name spree-postgres -p 5432:5432 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine
docker run -d --name spree-redis -p 6379:6379 redis:7-alpine
```

Then run the setup script:

```bash
cd server
bin/setup
bin/dev
```

`bin/setup` handles everything: installs Ruby (via [mise](https://mise.jdx.dev) if available, otherwise uses your system Ruby), system packages (libpq, vips), gems, and prepares the database.

By default the app connects to PostgreSQL at `localhost:5432` as user `postgres` with no password. Override with environment variables if needed:

```bash
DATABASE_HOST=127.0.0.1 DATABASE_PORT=5433 DATABASE_USERNAME=myuser bin/setup
```

Use `bin/setup --reset` to drop and recreate the database.

The app starts at `http://localhost:3000`.

**Emails in local dev:** By default emails are printed to the Rails log. To catch and preview emails with a web UI, run [Mailpit](https://mailpit.axllent.org) and set `SMTP_HOST`:

```bash
docker run -d --name mailpit -p 8025:8025 -p 1025:1025 axllent/mailpit
SMTP_HOST=localhost bin/dev
```

Then open `http://localhost:8025` to see all outgoing emails.

### Docker (TypeScript / frontend developers)

From the **repository root**:

```bash
docker compose up -d
```

This boots PostgreSQL, Redis, Mailpit, and the backend. The API is available at `http://localhost:3000`. The database is automatically created and migrated on first boot.

All outgoing emails are caught by Mailpit and viewable at `http://localhost:8025`.

To rebuild after changes:

```bash
docker compose build spree
docker compose up -d
```

To reset the database:

```bash
docker compose down -v
docker compose up -d
```

## Environment Variables

### Database

| Variable | Default | Description |
|---|---|---|
| `DATABASE_HOST` | `localhost` | PostgreSQL host |
| `DATABASE_PORT` | `5432` | PostgreSQL port |
| `DATABASE_USERNAME` | `postgres` | PostgreSQL user |

### Production

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection URL |
| `REDIS_URL` | Yes | Redis connection URL (caching, background jobs, Action Cable) |
| `SECRET_KEY_BASE` | Yes | Secret key for session encryption |

### Email (SMTP)

Spree works with any SMTP provider (Resend, Postmark, Mailgun, SendGrid, Amazon SES, etc.).

| Variable | Default | Description |
|---|---|---|
| `SMTP_HOST` | — | SMTP server address |
| `SMTP_PORT` | `587` | SMTP server port |
| `SMTP_USERNAME` | — | SMTP auth username |
| `SMTP_PASSWORD` | — | SMTP auth password |
| `SMTP_FROM_ADDRESS` | — | Default "from" email address |
| `RAILS_HOST` | `example.com` | Host used in mailer URLs |
