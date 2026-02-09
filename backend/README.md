# Spree Backend

A Rails application that serves as the Spree Commerce backend. It mounts the Spree engines (core, api, admin, emails, sample) from the `engines/` directory and provides the API and admin interface.

## Structure

```
backend/
├── Gemfile              # References engines via path
├── Dockerfile           # Multi-stage build for Docker
├── config/
├── db/
└── engines/
    ├── core/            # spree_core - models, services, business logic
    ├── api/             # spree_api - Storefront & Platform REST APIs
    ├── admin/           # spree_admin - admin dashboard
    ├── emails/          # spree_emails - transactional emails
    └── sample/          # spree_sample - sample seed data
```

## Setup

### Prerequisites

- Ruby 4.0+
- PostgreSQL 16+
- libvips (for image processing)

### Local Development (Ruby developers)

```bash
cd backend
bundle install
bin/rails db:prepare
bin/rails server
```

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

Replace `core` with `api`, `admin`, `emails`, or `sample` to test other engines.
