# Spree Backend

A Rails application that serves as the Spree Commerce backend. It mounts the Spree engines (core, api, admin, emails) from the `engines/` directory and provides the API and admin interface.

## Structure

```
backend/
├── Gemfile              # References engines via path
├── Dockerfile           # Multi-stage build for Docker
├── config/
├── db/
└── engines/
    ├── core/            # spree_core - models, services, business logic
    ├── api/             # spree_api - REST APIs and Webhooks
    ├── admin/           # spree_admin - admin dashboard
    ├── emails/          # spree_emails - transactional emails
    └── multi_store/     # spree_multi_store - multi-store setup, the only one licensed under AGPLv3, obtain a commercial license for production use at https://spreecommerce.org/enterprise/, not included by default
```

## Setup

### Local Development (Ruby developers)

PostgreSQL must be running before you start. If you have it installed locally, make sure it's running. Otherwise you can start it with Docker:

```bash
docker run -d --name spree-postgres -p 5432:5432 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine
```

Then run the setup script:

```bash
cd backend
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

Each engine has its own test suite. You must first install the engines root bundle, then the engine-specific one:

```bash
# Install shared dependencies (required once)
cd backend/engines
bundle install

# Run tests for a specific engine
cd core
bundle install
bundle exec rake test_app   # generates a dummy Rails app for testing
bundle exec rspec spec
```

Replace `core` with `api`, `admin`, `emails`, or `multi_store` to test other engines.
