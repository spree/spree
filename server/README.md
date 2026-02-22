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

PostgreSQL must be running before you start. If you have it installed locally, make sure it's running. Otherwise you can start it with Docker:

```bash
docker run -d --name spree-postgres -p 5432:5432 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine
```

Then run the setup script:

```bash
cd server
bin/setup
bin/rails server
```

`bin/setup` handles everything: installs Ruby (via [mise](https://mise.jdx.dev) if available, otherwise uses your system Ruby), system packages (libpq, vips), gems, and prepares the database.

By default the app connects to PostgreSQL at `localhost:5432` as user `postgres` with no password. Override with environment variables if needed:

```bash
DATABASE_HOST=127.0.0.1 DATABASE_PORT=5433 DATABASE_USERNAME=myuser bin/setup
```

Use `bin/setup --reset` to drop and recreate the database.

The app starts at `http://localhost:3000`.

### Docker (TypeScript / frontend developers)

From the **repository root**:

```bash
docker compose up -d
```

This boots PostgreSQL and the backend. The API is available at `http://localhost:3000`. The database is automatically created and migrated on first boot.

To rebuild after changes:

```bash
docker compose build backend
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
| `DATABASE_URL` | Yes | Primary database connection URL |
| `CACHE_DATABASE_URL` | No | Solid Cache database (falls back to `DATABASE_URL`) |
| `QUEUE_DATABASE_URL` | No | Solid Queue database (falls back to `DATABASE_URL`) |
| `CABLE_DATABASE_URL` | No | Action Cable database (falls back to `DATABASE_URL`) |
| `SECRET_KEY_BASE` | Yes | Secret key for session encryption |

## Running Engine Tests

Each engine has its own test suite. Navigate to the `spree/` directory and install dependencies:

```bash
# Install shared dependencies (required once)
cd spree
bundle install

# Run tests for a specific engine
cd core
bundle install
bundle exec rake test_app   # generates a dummy Rails app for testing
bundle exec rspec spec
```

Replace `core` with `api`, `admin`, or `emails` to test other engines.
