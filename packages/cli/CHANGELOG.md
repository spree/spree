# @spree/cli

## 2.4.5

### Patch Changes

- `spree build --production` is now a plain `docker build` from the project
root: the updated spree-starter Dockerfile normalizes its own build context
(detecting the `backend/` layout and a customized `apps/dashboard`), so the
staged-copy and named-build-context machinery is gone, and what the CLI
builds is byte-for-byte what Render/Railway build straight from the repo. A
root `.dockerignore` is written when missing so the context stays lean.
Pre-normalization Dockerfiles keep the old `backend/` context, with a
warning when a dashboard would be left out.

- Handle the Solid Queue single-container compose layout: new spree-starter
projects have no `worker` or `redis` services (jobs run inside Puma, stored
in Postgres), so `spree dev`, `restart`, `build`, and `db:reset` now target
the services the compose file actually defines instead of hard-coding
`web worker` — Sidekiq-era projects keep working unchanged. `spree logs
worker` on a worker-less project explains the in-process model and streams
web logs, pointing at the `/jobs` dashboard.

- Removed the `render.yaml` amendment from `spree add dashboard` — the
starter's Blueprint now deploys the backend as a Docker service built from
the repo root, which bakes `apps/dashboard` into the image by itself. The
scaffolded dashboard also pins its package manager (`packageManager` +
`pnpm-workspace.yaml` with `trustLockfile`) so image rebuilds don't break
when pnpm changes install-policy defaults — pnpm 11's `minimumReleaseAge`
re-validation fails any rebuild whose lockfile references day-old packages,
including every Spree release day (`@spree/*` is exempted from the gate).

## 2.4.4

### Patch Changes

- Streamline the post-setup summary for projects with the React Dashboard.
The dashboard's dev server is presented as THE admin — the
`cd apps/dashboard && pnpm dev` command with the admin credentials and a
dim pointer to the classic admin — instead of listing two admins where only
the classic one carried credentials. The image-served `/dashboard` build
stays a deployment detail in the docs. `spree dev` (and first-run setup)
now co-runs the dashboard's Vite dev server with the Docker stack — one
command brings up the whole dev environment, its output joins the stream
with a `dashboard |` prefix, Ctrl+C stops everything, a dashboard crash
warns without taking the API down, and `--open` waits for Vite and opens
the URL it actually reports (ports auto-bump when 5173 is taken). `spree add dashboard` gains
`--quiet` to skip its summary note when a wrapping tool (create-spree-app)
prints its own. Projects without the dashboard keep the classic summary
unchanged.

## 2.4.3

### Patch Changes

- Fix dashboard logins dying on CORS in scaffolded apps. `spree add
dashboard` wrote `VITE_SPREE_API_URL=http://localhost:<port>` into
`apps/dashboard/.env.local` — but that variable is the SDK's switch to
absolute cross-origin URLs (meant for production deploys on a different
origin), so requests bypassed the Vite dev proxy and the browser blocked
them (`localhost:5173` → `localhost:3000` is cross-origin; the auth cookie
is `SameSite=Lax` on top). The scaffold now writes `VITE_API_PROXY_TARGET`
(the proxy target — the SPA stays same-origin, the SDK stays on relative
URLs), the dashboard template's Vite config reads it (via `loadEnv` — Vite
doesn't load `.env` files into `process.env` for configs), and the CLI
writes or repairs `.env.local` automatically: on scaffold, on every
`spree dev` boot, and on a `spree add dashboard` re-run — covering fresh
clones (the file is gitignored) and projects scaffolded by older CLI
versions. Repair rewrites only the broken line; everything else in the
file is preserved.

## 2.4.2

### Patch Changes

- `spree dev` on a project that was never set up now runs the full first-run
flow automatically (pull fresh images, start services, seed the database,
configure API keys) instead of a bare `docker compose up`. A bare `up` never
pulls, so a mutable tag (`latest`) cached weeks ago by another project
silently booted an old Spree whenever the first boot happened through
`spree dev` — a `--no-start` scaffold, an interrupted create-spree-app run,
or a fresh clone. A setup that was itself interrupted partway (e.g. Ctrl+C
during the first image pull) is also detected and completed on the next
`spree dev`, for projects scaffolded by create-spree-app 1.1.1+. The
sample-data choice create-spree-app persists in `.env`
(`SPREE_SAMPLE_DATA`) is honored, so a deferred first run keeps the answer
given at scaffold time. Setup also installs `apps/storefront` and
`apps/dashboard` dependencies when they're missing (a fresh clone, or a
scaffold whose install step failed) — mirroring create-spree-app's per-app
install steps — so every app is runnable with `pnpm dev` right after.
Already-initialized projects are untouched: later boots never pull, dev
stays offline-friendly, and upgrades stay explicit via `spree update`.

## 2.4.1

### Patch Changes

- Re-embed the dashboard-starter template against `@spree/dashboard` 0.10.1
and `@spree/admin-sdk` ^0.6.0. 0.10.1 ships the Vite integration compiled to
JS — registry installs of 0.10.0 failed the host build with
`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING` when `vite.config.ts` imported
`@spree/dashboard/vite` — and admin-sdk 0.5.0 lacks the Admin API endpoints
and types the dashboard consumes (the 0.x caret in the previous template pin
never resolves to 0.6.0). The `spree dashboard plugin` scaffold now pins
`@spree/admin-sdk` ^0.6.0 as well.

## 2.4.0

### Minor Changes

- Add `spree add dashboard` — scaffolds the React Dashboard starter (Developer
Preview), bundled inside the CLI with version pins matching the release, into
`apps/dashboard/` of an existing project and points it at the project's API
(`--template <path|git-url>` overrides the bundled copy). Also make
`spree plugin new` fully non-interactive: every prompt has a flag
(`--ruby-name`, `--module-name`, `--npm-scope`, `--author`, `--author-email`,
`--license`, `-y`), with author details defaulting from git config.

## 2.3.9

### Patch Changes

- Add `spree shell` (alias: `spree bash`) — open an interactive bash shell inside the web container, the system-shell sibling of `spree console` (Rails) and `spree db:console` (psql). When the web container is down — a crash-looping stack is exactly when a shell is most useful — it falls back to a one-off container against the same volumes, with postgres cold-started and health-waited first.

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
