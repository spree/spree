# create-spree-app

## 1.0.0

### Major Release

Stable release of `create-spree-app` for Spree Commerce 5.4.0. Scaffolds a complete Spree project with Docker, Meilisearch, and optional Next.js storefront. Now requires stable `@spree/cli` ^2.0.0.

## 0.5.1

### Patch Changes

- Bump @spree/cli dependency to 2.0.0-beta.7 which includes search index initialization during `spree init`.

## 0.5.0

### Minor Changes

- Add Meilisearch to docker-compose.yml for built-in full-text search with typo tolerance, relevance ranking, and faceted filtering. Meilisearch runs automatically alongside PostgreSQL and Redis — no additional setup needed for development.

## 0.4.0

### Minor Changes

- Always include `backend/` directory (cloned from spree/spree-starter) with full Rails app for backend customization. Add `docker-compose.dev.yml` for local builds. Add `spree eject` script. Storefront is now optional via `--no-storefront` flag. Upgrade to PostgreSQL 18.

## 0.3.3

### Patch Changes

- Bump `@spree/cli` dependency to `2.0.0-beta.5`

## 0.3.2

### Patch Changes

- Bump `@spree/cli` dependency to `2.0.0-beta.4`

## 0.3.1

### Patch Changes

- Updated storefront repository URL from `spree/nextjs-starter-spree` to `spree/storefront`

## 0.3.0

### Minor Changes

- Integrate `@spree/cli` for day-to-day project management — scaffolded projects now include `@spree/cli` as a dependency with convenience scripts (`spree dev`, `spree stop`, `spree update`, `spree logs`, `spree console`, etc.)
- Delegate first-run setup to `spree init` — database seeding, API key creation, sample data loading, and browser open are now handled by the CLI instead of the scaffolder
- Rewrite Docker Compose template: switch from Solid Queue to Sidekiq + Redis, add Mailpit for local email, use YAML anchors for DRY config
- Use sequential port selection via `get-port` with `portNumbers()` range instead of random ports
- Add Mailpit URL to generated README

## 0.2.2

### Patch Changes

- Replace giget with `git clone --depth 1` for downloading storefront template — fixes EACCES cache permission errors and reduces bundle size by 75%

## 0.2.1

### Patch Changes

- Fix EACCES permission error when downloading storefront template by pre-creating the giget cache directory

## 0.2.0

### Minor Changes

- Add dynamic port detection using get-port — if port 3000 is in use during scaffold, automatically picks the next available port. Add `--port` CLI flag for explicit override. Add `npm run stop` command.

## 0.1.2

### Patch Changes

- Add background worker service to Docker Compose for Solid Queue job processing, rename service from `spree` to `web`/`worker`

## 0.1.1

### Patch Changes

- Fix Docker compose template: use DATABASE_URL for production, set separate database URLs for cache/queue/cable, disable SSL for local development, and load SECRET_KEY_BASE via env_file
