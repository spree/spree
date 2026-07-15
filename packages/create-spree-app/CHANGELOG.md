# create-spree-app

## 1.1.1

### Patch Changes

- A finished `create-spree-app` run now always means a working app. The
optional storefront and React Dashboard phases used to abort the whole
scaffold on failure — before the final setup phase (`spree init`: fresh
image pull, seeded database, API keys) ever ran — leaving a project whose
first boot silently started a stale, locally cached Spree image. Those
phases now warn and continue with a recovery command, so setup always runs.
When services can't start during scaffolding (`--no-start`, Docker off), the
first `spree dev` completes setup automatically (requires `@spree/cli`
2.4.2), honoring the sample-data choice now persisted in `.env`
(`SPREE_SAMPLE_DATA`), and the printed next steps plus the generated README
reflect that — nobody has to know `spree init` exists.

## 1.1.0

### Minor Changes

- Offer the React Dashboard (Developer Preview) as an optional component: a new
prompt (and `--no-dashboard` flag) scaffolds it into `apps/dashboard/` by
delegating to the project-local `spree add dashboard` (the CLI bundles the
starter template with version pins matching its release), and wires the
README, CLAUDE.md, and Dependabot config.

New projects now default to **pnpm** when it's installed — it's what the
Spree packages and docs are built around. An explicit invoking agent
(`pnpm create spree-app`, `yarn create spree-app`) and the
`--use-npm`/`--use-yarn`/`--use-pnpm` flags still win, and npm remains the
fallback when pnpm is absent. The generated README, CLAUDE.md, and next-steps
output now render commands for the chosen package manager instead of
hardcoding npm.

## 1.0.8

### Patch Changes

- Relocate the generated project's Render Blueprint (`render.yaml`) to the repository root and add `rootDir: backend` to every buildable service. In the wrapper layout the Rails app lives under `backend/`, so a Blueprint left in that subdirectory is invisible to Render and, without `rootDir`, its services build from the wrong directory — the deploy fails. The commented-out worker template is adjusted too, so uncommenting it still deploys correctly. Managed services (Redis, database) are left untouched.

## 1.0.7

### Patch Changes

- Fix and tidy the generated project's CI for the nested `backend/` layout. The relocated `backend-ci.yml` now points `ruby/setup-ruby` and the `bin/rails`/`bundle` steps at `backend/`, so `ruby/setup-ruby` finds `.ruby-version` instead of failing with "input ruby-version needs to be specified". The starter's `release.yml` (which publishes the official Spree image) and its standalone `README.md` are no longer carried into the generated project.

## 1.0.6

### Patch Changes

- Improve generated README and post-create next steps with links to the Spree documentation, Discord, and CLI.

## 1.0.5

### Patch Changes

- Fix the `spree api` product-create example in the generated project README and CLAUDE.md. The sample payload now ships a `prices` array with a quoted string amount (`"29.99"`) instead of an unsupported top-level `price` scalar, matching the Admin API's expected shape.

## 1.0.4

### Patch Changes

- Generated projects now document the Admin API CLI: `api`/`auth`/`api-key` passthrough scripts in `package.json`, an Admin API section in the README and CLAUDE.md showing `npx spree api get products` (works against the read-only key minted during setup), and the global-install option for a bare `spree` command.

- Scaffolded `.gitignore` now excludes `.spree/` — the local Admin API credentials directory used by `spree api` / `spree auth`.

## 1.0.3

### Patch Changes

- Fix `docker-compose.dev.yml` to bind-mount `./backend` instead of the project root. The scaffolded dev compose adjusted the build context for the wrapper layout but kept the starter's `.:/rails` source mount, so `spree eject` failed with `exec: "bin/rails": stat bin/rails: no such file or directory`.

## 1.0.2

### Patch Changes

- Scaffolded projects now reference the Spree agent skills (`npx skills add spree/agent-skills`) in the generated AGENTS.md/CLAUDE.md and post-create next steps, and the generated README documents the new `spree dev` foreground behavior (streams logs, Ctrl+C stops the app).

## 1.0.1

### Patch Changes

- Remove stale Mailpit references from the generated project README. Mailpit is no longer part of the docker-compose services.

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
