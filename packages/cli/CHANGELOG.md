# @spree/cli

## 2.3.8

### Patch Changes

- Add `spree rspec` — run the RSpec suite inside the web container without spelling out `spree bundle exec rspec`. Everything after `rspec` is forwarded verbatim (`spree rspec spec/models/spree/brand_spec.rb:15`, `spree rspec --format documentation`), `RAILS_ENV=test` is forced so tests always hit the test database, and when the stack is down the command falls back to a one-off container that cold-starts postgres first.

## 2.3.7

### Patch Changes

- Compile the admin dashboard stylesheet on ejected projects. Ejecting bind-mounts `./backend` over the image's precompiled `app/assets/builds`, and the dev stack never runs `assets:precompile`, so `spree/admin/application.css` was missing and every admin page 500'd. `spree eject` now compiles it, and `spree dev` compiles it if missing and then runs the Tailwind watcher so admin edits recompile live.

## 2.3.6

### Patch Changes

- Fix `spree --version` reporting a stale hardcoded `2.0.0` instead of the installed CLI version. The version is now read from the package's `package.json` at runtime, so `spree -V` and `npx spree -V` always match the release you have installed.

## 2.3.5

### Patch Changes

- Fix `spree db:reset` and `spree console` when the stack is down or already serving. `db:reset` now self-heals from any state: it stops the web + worker containers holding open Postgres connections (which a plain `DROP DATABASE` rejects), then runs the drop/create/migrate/seed chain in a one-off `docker compose run --rm web` container whose dependencies cold-start automatically — so a reset works whether the stack is up, partially up, or fully stopped, and a stale host DB client (TablePlus/psql on port 5433) blocking the drop now produces an actionable hint instead of a raw error. `spree console` falls back to a one-off container when web is down (mirroring `spree bundle`) instead of failing, and `spree db:console` guides you to start the stack when Postgres isn't running. Both new fallbacks refuse cleanly in monorepo edge projects, consistent with the other commands.

## 2.3.4

### Patch Changes

- Fix `spree upgrade` on create-spree-app projects. Running it from the `backend/` directory no longer fails on a missing `.env` — the CLI now resolves to the project root automatically. When the bundle is out of sync (e.g. an un-checked-out git gem source), it surfaces the real bundler error and points you at `spree bundle install` instead of a misleading "No Spree gems detected". And it now refuses early with a clear message when the stack is down or in a monorepo edge project, rather than failing deep in a Docker command.

## 2.3.3

### Patch Changes

- Fix an intermittent `failed to mkdir … file exists` error on the first `spree eject` / `spree dev` / `spree init` / `spree update` of a fresh project. On a cold `bundle_cache` volume the `web` and `worker` containers raced to populate it; the CLI now brings `web` up alone first so it seeds the volume uncontended before the rest of the stack starts.

## 2.3.2

### Patch Changes

- `spree api status` now shows the API key's live scopes fetched from the server instead of the stale snapshot saved at mint time. Falls back to the local snapshot (clearly labelled) when the server can't report scopes.

## 2.3.1

### Patch Changes

- Fix `spree api` product-create examples in the CLI help text and docs. A product's price lives on its variants, so the example now ships a `prices` array (for a simple product) instead of an unsupported top-level `price` scalar, and monetary amounts are quoted strings (`"29.99"`) to match the API's read/write format and preserve localized input.

## 2.3.0

### Minor Changes

- `spree init` now mints a read-only secret key and saves it to `.spree/credentials.json`, so `spree api` works immediately without a first-use minting round-trip. The setup summary shows both the Store API publishable key and the Admin API secret key.

## 2.2.1

### Patch Changes

- Fix `npm install` failing with `EUNSUPPORTEDPROTOCOL "workspace:"`. `@spree/admin-sdk` is bundled into the CLI at build time, so it's now a dev dependency — the published `package.json` no longer carries an unresolvable `workspace:` runtime dependency.

## 2.2.0

### Minor Changes

- New `spree api` and `spree auth` command groups — a generic Admin API client (`get`/`post`/`patch`/`delete`) built into the CLI:

  - `spree api get|post|patch|delete <path>` — generic verbs with Ransack `-q` filters, `--sort`/`--page`/`--limit`/`--expand`/`--fields`, and JSON bodies from inline/`@file`/stdin
  - `spree api endpoints` / `spree api schema` — offline schema introspection over a bundled OpenAPI snapshot, including each endpoint's required scope
  - `spree api status` — resolved credentials + server reachability
  - `spree auth login|status|logout|list` — named profiles in `~/.config/spree/config.json`
  - `spree completion bash|zsh|fish` — shell completion for resource paths, Ransack predicate stems, and scope names, resolved offline from the bundled spec
  - Zero-config credentials inside a project: a read-only key is minted via the dev stack on first use and stored in `.spree/credentials.json`. For other servers, `SPREE_API_KEY` is enough — the host defaults to `http://localhost:3000`; set `SPREE_BASE_URL` or save a profile for a remote store.

  Output is JSON: indented and colored in a terminal, compact and uncolored when piped (clean for `jq`).

  Works against any Spree 5.5+ instance.

- `spree api-key create` now supports scopes for secret keys via `--scopes` (comma-separated, e.g. `--scopes read_orders,write_products`) or an interactive prompt defaulting to `read_all`. Required against Spree 5.5+ servers, where secret keys must carry at least one scope.

## 2.1.2

### Patch Changes

- `spree generate controller` now forwards to the Rails `controller` generator instead of the non-existent `spree:controller`.

## 2.1.1

### Patch Changes

- `spree eject` now repairs dev compose files scaffolded with the broken `.:/rails` bind-mount and runs `db:prepare` after switching to the dev stack. The dev image bypasses the entrypoint that creates the database in the prebuilt image, so without this the ejected stack booted against a missing `spree_development` database.

## 2.1.0

### Minor Changes

- `spree dev` now runs the app in the foreground like every other dev server (`vite dev`, `bin/dev`): it streams web + worker logs and `Ctrl+C` stops them, while the database containers keep running for a fast next boot — `spree stop` remains the full shutdown. Previously `Ctrl+C` only detached from the logs and left everything running. Real compose failures (daemon down, port conflict, bad config) now exit with the underlying code instead of printing a clean shutdown message; a `Ctrl+C` stop still ends cleanly.

  Add `spree restart` — restarts `web` + `worker` in place (same image, same volumes, fresh Rails process). For `config/initializers` changes and anything Zeitwerk doesn't reload; it does not pick up Gemfile or compose changes.

  `spree bundle` now works when the stack is down: if the `web` container isn't running — for example after a `Gemfile.lock` change crash-loops the boot, which is exactly when bundler is needed — it runs bundler in a one-off container against the same `bundle_cache` volume instead of failing on `exec`.

  `spree dev` and `spree build` detect monorepo edge projects (`SPREE_PATH` in `.env`) and refuse with a pointer to the matching `pnpm server:*` script, instead of materializing the wrong compose config against the running edge stack.

  `spree migrate` prints a header for each step and a completion note — previously a fully up-to-date run produced no output at all, leaving no signal that anything ran.

  `spree upgrade`'s closing "Next steps" panel now includes the SDK side of the upgrade: when the project has the conventional `apps/storefront` consuming `@spree/sdk`, it names the currently-declared version and reminds you to bump it to the release matching the new Spree version.

- Add `spree generate`, `spree migrate` (+ `migrate:rollback`, `migrate:status`), `spree build`, `spree db:reset`, `spree db:console`, and `spree routes`. `spree generate` auto-prefixes `spree:` so `spree generate model Brand name:string` invokes the Spree generator. `spree db:reset` and `spree build --reset-bundle` are destructive and prompt by default; pass `--yes` to skip the prompt in CI. `spree build` targets the active `docker-compose.yml` (the same file `spree dev` runs) and refuses with a pointer to `spree eject` when it has no `build:` section; in monorepo edge projects it points at `pnpm server:build`.

  `spree eject` no longer runs a separate `docker compose build` step (the dev compose builds on first `up -d` automatically). Its description and post-eject hints now point at `spree bundle add` for gems and `spree build` for Dockerfile / `.ruby-version` changes.

- Add `spree exec`, `spree rails`, `spree bundle`, `spree rake`, and `spree task` as generic passthrough commands so any Rails / bundler / rake invocation is reachable through `spree` without `docker compose exec` incantations. `spree task <name>` auto-prefixes `spree:` to save the namespace prefix on the common path. `spree console` is rewired onto the same helper.

- Add `spree upgrade` — sequencer around the dev upgrade flow. Runs `bundle update`, applies pending migrations, then delegates to `bin/rake spree:upgrade` (which executes the version-specific data backfills from a manifest shipped inside `spree_core`). On production, only the rake task runs — your deploy pipeline handles `bundle install` and `db:migrate`. Flags `--plan`, `--step <id>`, `--to <version>`, `--yes` map to env vars (`DRY_RUN`, `STEP`, `TO`) on the rake task so the same arguments work on both surfaces.

### Patch Changes

- Run `spree:search:reindex` during `spree init` after sample data is loaded. This initializes the Meilisearch search index so product search works immediately after setup.

## 2.0.0

### Major Release

Stable release of `@spree/cli` for Spree Commerce 5.4.0. Docker-based project management CLI with `spree init`, `spree start`, `spree stop`, `spree eject`, and `spree update` commands.

## 2.0.0-beta.7

### Patch Changes

- Run `spree:search:reindex` during `spree init` after sample data is loaded. This initializes the Meilisearch search index so product search works immediately after setup.

## 2.0.0-beta.6

### Minor Changes

- Add `spree eject` command to switch from prebuilt Docker image to building from local `backend/` directory. Also update port detection to read `SPREE_PORT` from `.env`.

## 2.0.0-beta.5

### Patch Changes

- Automatically update storefront `.env.local` with the real API key during `spree init`

## 2.0.0-beta.4

### Patch Changes

- Pull latest Docker image during `spree init` to ensure fresh setups always use the newest version
- Show Docker pull progress output during `spree init` and `spree update` instead of a spinner
