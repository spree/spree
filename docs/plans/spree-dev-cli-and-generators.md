# Spree Dev CLI + Generators — DX for TypeScript developers

**Status:** Spec, not approved.
**Audience:** TS developers who want to customize Spree without learning Docker internals or installing Ruby.
**Owners:** TBD.

## Project structure (what a user actually has)

`create-spree-app` scaffolds:

```text
my-spree-app/
├── backend/                  # the Rails app (cloned from spree-starter)
│   ├── Dockerfile
│   ├── Gemfile
│   ├── app/, config/, db/ …
│   └── docker-compose{,.dev}.yml   (templates — copied up to root during scaffold)
├── apps/storefront/          # Next.js (optional)
├── docker-compose.yml        # active compose at project root
├── docker-compose.dev.yml    # dev compose at project root
├── .env
└── package.json              # has @spree/cli as a dep
```

`create-spree-app/src/scaffold.ts:58–65` copies the compose files from `backend/` up to the project root and rewrites `context: .` → `context: ./backend` so the build context points at the Rails app. Everything in this doc operates against the **project root** compose files and the **`./backend`** Rails app. (The `server/` directory in the `spree/spree` monorepo is the local dev clone of `spree-starter` — irrelevant to user projects.)

## Problem

A TS developer who runs `pnpm dlx create-spree-app` lands in a working prebuilt-image setup. The moment they want to customize the backend — add a `Brand` model, expose an endpoint, write a subscriber — they hit three walls:

1. **`spree eject` means rebuild-on-every-edit.** Today it swaps `docker-compose.yml` for `docker-compose.dev.yml`, which builds from `./backend/Dockerfile`. The Dockerfile `COPY . .`s the source into the image and the compose file mounts only `storage_data:/rails/storage`. There is no source bind-mount, no bundle cache volume, and the env carries `RAILS_ENV=production` + `BUNDLE_DEPLOYMENT=1` + `BUNDLE_WITHOUT=development:test` from the Dockerfile. So every edit needs `docker compose build`; Zeitwerk reloading never engages; dev gems are absent.
2. **The CLI has no escape hatch.** `spree console`, `spree user create`, `spree api-key` each wrap a specific Rails task. There is no `spree exec`, `spree rails`, `spree bundle`, or `spree migrate`. Anything not pre-wrapped requires the developer to know the underlying `docker compose exec web …` incantation — exactly the knowledge the CLI exists to hide.
3. **Generators stop at the model.** `spree:model` (core/lib/generators/spree/model/) emits a model + migration. There is no `spree:api_resource` to scaffold a v3-conformant Store/Admin controller, serializer, route entry, request spec, and OpenAPI fragment. A new resource is hours of conformance work and a likely review back-and-forth on conventions (prefixed IDs, `{ data, meta }` envelope, expand, keyset pagination, Store-vs-Admin exposure split).

The fix is three independent tracks, layered: (1) make the dev container hot-reload, so `eject` stops meaning rebuild-hell; (2) ship a generic CLI passthrough plus a thin set of hot-path wrappers, like Laravel Sail; (3) add `spree:api_resource` so v3-conformance is correct-by-construction. (4) is the MCP/skill layer over the same surface — covered last and deferred to a follow-up.

The deliverables in this doc are concrete diffs against the project-root `docker-compose.dev.yml` (shipped from `spree-starter` and pulled into user projects by `create-spree-app`), `packages/cli/src/`, and the addition of `core/lib/generators/spree/api_resource/`. Devcontainer support is noted as a follow-up; OrbStack/virtiofs is a docs note, not code.

---

## Track 1 — Hot-reload dev container

### Goal

After `spree eject`, the developer edits a file under `./backend/` and the next request reflects the change. No `spree build`, no container restart, no Ruby on the host. Adding a gem stays inside the container (`spree bundle add …`) but does not require a full rebuild — gems land in a persisted volume.

### The four things to change

Each one is needed; cutting any one breaks the loop.

| Change | Why it's required |
|---|---|
| **Bind-mount `./backend:/rails`** | Edits on the host reach the container instantly. Generator output lands on the host. |
| **Named volume on `BUNDLE_PATH` (`/usr/local/bundle`)** | The bind-mount would otherwise shadow the gems baked into the image. The named volume sits over the bundle path so gems persist across `spree bundle add` without a rebuild. |
| **`RAILS_ENV=development`, unset `BUNDLE_DEPLOYMENT`, `BUNDLE_WITHOUT=""`** | The Dockerfile bakes production env. Without overrides the container boots in production mode (no reloading, dev gems absent) even with bind-mounts. |
| **Override entrypoint/command** | The Dockerfile's `ENTRYPOINT bin/docker-entrypoint` runs `db:prepare` and assets precompile every boot — wrong for dev. Use a thin dev command instead. |

### Concrete diff: `docker-compose.dev.yml` (project root; shipped from `spree-starter`'s `backend/` template)

Below is the full proposed file. Anchors and the prod-style `bin/docker-entrypoint` go away; bind-mount + bundle volume + dev env + a node_modules-style listener arrangement come in. Volumes that don't change (postgres, redis, meilisearch, storage) are unchanged.

```yaml
# Development: bind-mounts ./backend into the container. Edits are hot.
# Use `spree dev` (which runs `docker compose up -d` against this file).
#
# Adding a gem: `spree bundle add some_gem` — gems persist in the bundle_cache volume.
# Changing the Dockerfile or .ruby-version: `spree build` to rebuild the image.

x-app: &app
  build:
    context: .
    dockerfile: Dockerfile
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
    meilisearch:
      condition: service_healthy
  env_file: .env
  environment: &app-env
    DATABASE_URL: postgres://postgres@postgres:5432/spree_development
    REDIS_URL: redis://redis:6379/0
    SECRET_KEY_BASE: ${SECRET_KEY_BASE}
    RAILS_FORCE_SSL: "false"
    RAILS_ASSUME_SSL: "false"
    MEILISEARCH_URL: http://meilisearch:7700
    # --- dev overrides on top of the Dockerfile's production defaults ---
    RAILS_ENV: development
    BUNDLE_DEPLOYMENT: "0"
    BUNDLE_WITHOUT: ""
    BUNDLE_PATH: /usr/local/bundle
    BOOTSNAP_CACHE_DIR: /rails/tmp/cache/bootsnap
  volumes:
    # bind-mount the source so host edits are live in the container
    - ./backend:/rails
    # named volume over BUNDLE_PATH so the bind-mount doesn't shadow installed gems,
    # and so `bundle add` persists across container restarts without a rebuild
    - bundle_cache:/usr/local/bundle
    # named volume for storage (uploads, ActiveStorage local disk)
    - storage_data:/rails/storage
    # named volume for tmp so bootsnap + cache don't churn the host
    - tmp_cache:/rails/tmp

services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
      PGDATA: /var/lib/postgresql/18/docker
    ports:
      # forwarded for native DB clients (TablePlus, DataGrip, psql) — Track 1 add
      - "${SPREE_DB_PORT:-5433}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql
    healthcheck:
      test: pg_isready -U postgres
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: redis-cli ping
      interval: 5s
      timeout: 5s
      retries: 5

  meilisearch:
    image: getmeili/meilisearch:latest
    volumes:
      - meilisearch_data:/meili_data
    ports:
      - "7700:7700"
    healthcheck:
      test: curl -f http://localhost:7700/health || exit 1
      interval: 5s
      timeout: 5s
      retries: 5

  web:
    <<: *app
    # bypass bin/docker-entrypoint (which does db:prepare + assets:precompile —
    # not what we want in dev). Run setup explicitly via `spree init`.
    entrypoint: []
    command: ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
    ports:
      - "${SPREE_PORT:-3000}:3000"
    healthcheck:
      test: curl -f http://localhost:3000/up || exit 1
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  worker:
    <<: *app
    entrypoint: []
    command: ["bundle", "exec", "sidekiq"]
    environment:
      <<: *app-env
      RAILS_MAX_THREADS: ${SIDEKIQ_DB_POOL:-27}

volumes:
  postgres_data:
  redis_data:
  meilisearch_data:
  storage_data:
  bundle_cache:
  tmp_cache:
```

Notes on the diff:

- **`DATABASE_URL` switches `spree_production` → `spree_development`.** This matches `RAILS_ENV=development` (Rails would otherwise look for the wrong DB). `spree init` creates it; `spree migrate` runs against it.
- **The bind-mount + bundle-cache layering is the trick.** Without the named volume on `/usr/local/bundle`, the bind-mount of `./backend → /rails` shadows the gems baked into the image (since the build stage installs to `/usr/local/bundle` and copies them in). The named volume re-overlays gems on top, and persists `bundle add` results across boots.
- **Anchored `volumes:` on `*app`** means `web` and `worker` share the same mount set. Don't define `volumes:` on the service or it'll override the anchor — Compose merges keys, but it replaces lists.
- **`entrypoint: []` is intentional.** `bin/docker-entrypoint` runs `db:prepare` (which would auto-create the DB and silently swallow migration ordering issues) and `bootsnap precompile`. Both are wrong in dev. `spree init` does the explicit equivalent (`db:create`, `db:migrate`, `db:seed`).
- **`SPREE_DB_PORT=5433` default**, not 5432, to avoid colliding with a host-native Postgres if the user has one.

### Adding and updating gems — no image rebuild

The `bundle_cache` named volume is the persistent gem store. The dev image's role is "seed the volume on first creation with a known-good baseline"; after that, the volume is the source of truth.

| Scenario | Command | Image rebuild? |
|---|---|---|
| Add a gem | `spree bundle add foo` | No — installs into `bundle_cache` |
| Update a gem | `spree bundle update <gem>` | No |
| Pull teammate's Gemfile.lock change | `spree bundle install` | No |
| `.ruby-version` bump | `spree build` + see gotcha below | Yes |
| Dockerfile apt package change | `spree build` | Yes |

**Gotcha (documented; not a code change):** Docker initializes a named volume from the image's mount-path contents *only the first time the volume is created*. After `spree build` for a `.ruby-version` bump, the rebuilt image carries gems compiled against the new Ruby, but the existing `bundle_cache` volume still holds gems from the old Ruby — they'll fail to load. Fix: `docker volume rm <project>_bundle_cache` (or, in the CLI: `spree build --reset-bundle` — a small additional flag to wipe the bundle volume in the same operation; trivial to add to the `build` command).

### `eject` semantics post-change

`spree eject` keeps its current job — copy `docker-compose.dev.yml` over `docker-compose.yml` — but the meaning changes: the dev compose is now the live-edit configuration, not a "build from local source" configuration. After `eject`:

- File edits in `./backend/` are live (Zeitwerk).
- `Gemfile` edits use `spree bundle add <gem>` (runs inside the container, persists to `bundle_cache`).
- `Dockerfile` or `.ruby-version` edits require `spree build` (new command, see Track 2).

### Diff: `packages/cli/src/commands/eject.ts`

```diff
-      console.log(`\n${pc.bold('Building backend from local source...')}\n`)
-      await dockerCompose(['build'], ctx.projectDir, { stdio: 'inherit' })
-
-      console.log(`\n${pc.bold('Restarting services...')}\n`)
+      console.log(`\n${pc.bold('Switching to dev compose (bind-mounts ./backend)...')}\n`)
       await dockerCompose(['up', '-d'], ctx.projectDir, { stdio: 'inherit' })

       p.note(
         [
-          `Backend now builds from ${pc.bold('./backend')}`,
+          `Backend is now bind-mounted from ${pc.bold('./backend')} — edits are live.`,
           '',
           'You can now customize:',
-          `  ${pc.dim('backend/Gemfile')}          — add gems`,
+          `  ${pc.dim('backend/app/')}             — models, controllers, services — instant reload`,
+          `  ${pc.dim('backend/Gemfile')}          — add gems via ${pc.bold('spree bundle add <gem>')}`,
           `  ${pc.dim('backend/app/')}             — models, controllers, etc.`,
           `  ${pc.dim('backend/config/')}          — Rails configuration`,
           '',
-          `Run ${pc.bold('npx spree dev')} to restart with your changes.`,
+          `Rebuild only on Dockerfile / .ruby-version changes: ${pc.bold('spree build')}`,
         ].join('\n'),
         'Ejected!',
       )
```

`spree build` is the new "I actually changed the image" escape hatch — see Track 2.

---

## Track 2 — CLI: passthrough first, then wrappers

### Goal

A TS developer can run any Rails / bundler / shell command inside the dev container without knowing about Docker. Hot-path commands get a short alias; everything else goes through a generic passthrough.

### Design principle: passthrough is the floor

The hot wrappers (`spree generate`, `spree migrate`, `spree bundle`, `spree build`) save keystrokes for the common cases. The generic passthrough (`spree exec`, `spree rails`, `spree bundle`) guarantees nothing is ever blocked on a command we forgot to wrap. **Build passthrough first, wrappers second** — the wrappers can never invalidate the floor.

### New commands

| Command | Maps to | Notes |
|---|---|---|
| `spree exec <cmd…>` | `docker compose exec web <cmd…>` | Generic escape hatch. Anything works. |
| `spree rails <args…>` | `docker compose exec web bin/rails <args…>` | Short for `spree exec bin/rails …` |
| `spree rake <task> [args…]` | `docker compose exec web bin/rake <task> [args…]` | Direct rake passthrough. `spree rake spree:price_history:seed`, `spree rake spree:channels:create_defaults`. Use this for data backfills, upgrade tasks, and anything not wrapped by a higher-level command. Args after `--` are forwarded as rake task args (`spree rake spree:foo -- BAR=baz`). |
| `spree task <name> [args…]` | alias for `spree rake spree:<name>` | Shorter for Spree-namespaced tasks: `spree task price_history:seed` ≡ `spree rake spree:price_history:seed`. |
| `spree bundle <args…>` | `docker compose exec web bundle <args…>` | `spree bundle add stripe`, `spree bundle install`, `spree bundle outdated`. Gems land in `bundle_cache`. |
| `spree generate <name> [args…]` | `docker compose exec web bin/rails g spree:<name> [args…]` | Translates `spree generate model Brand …` into `bin/rails g spree:model Brand …`. Auto-prefixes `spree:`. |
| `spree migrate` | `docker compose exec web bin/rails db:migrate` | Hot path — first thing after every generator. |
| `spree migrate:rollback [STEP=n]` | `docker compose exec web bin/rails db:rollback` | |
| `spree migrate:status` | `docker compose exec web bin/rails db:migrate:status` | |
| `spree db:reset` | `docker compose exec web bin/rails db:drop db:create db:migrate db:seed` | Common nuke-and-pave. Prompts for confirmation. |
| `spree routes [-g pattern]` | `docker compose exec web bin/rails routes [-g …]` | |
| `spree build` | `docker compose exec` not viable — `docker compose build web` | Used after Dockerfile / `.ruby-version` changes. Not after Gemfile changes (use `spree bundle add` for those). |
| `spree db:console` | `docker compose exec postgres psql -U postgres spree_development` | One-liner for psql without remembering credentials. (Native clients use the forwarded `SPREE_DB_PORT`.) |

The existing commands (`spree dev`, `spree init`, `spree stop`, `spree logs`, `spree console`, `spree user`, `spree api-key`, `spree open`, `spree seed`, `spree sample-data`, `spree update`, `spree eject`) stay.

### Implementation sketch

A single new helper, `dockerComposeExec`, generalizes what `railsConsole` does today (`packages/cli/src/docker.ts:33–37`) and accepts arbitrary argv:

```ts
// packages/cli/src/docker.ts — add alongside existing helpers

export async function dockerComposeExec(
  argv: string[],
  projectDir: string,
  options: { service?: string; tty?: boolean; env?: Record<string, string> } = {},
): Promise<void> {
  const { service = 'web', tty = true, env } = options
  const args = ['compose', 'exec']
  if (!tty) args.push('-T')
  if (env) for (const [k, v] of Object.entries(env)) args.push('-e', `${k}=${v}`)
  args.push(service, ...argv)

  await execa('docker', args, { cwd: projectDir, stdio: 'inherit' })
}
```

Then `exec`, `rails`, `bundle`, `migrate`, `generate`, `routes` are each one file in `packages/cli/src/commands/` that calls `dockerComposeExec` with a different prefix. Example:

```ts
// packages/cli/src/commands/generate.ts (new)
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

export function registerGenerateCommand(program: Command): void {
  program
    .command('generate <name> [args...]')
    .alias('g')
    .description('Run a Spree generator (e.g. `spree generate model Brand name:string`)')
    .allowUnknownOption(true)              // pass through `--skip-tests` etc.
    .action(async (name: string, args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExec(
        ['bin/rails', 'g', `spree:${name}`, ...args],
        ctx.projectDir,
      )
    })
}
```

```ts
// packages/cli/src/commands/exec.ts (new) — the universal escape hatch
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

export function registerExecCommand(program: Command): void {
  program
    .command('exec <command...>')
    .description('Run an arbitrary command inside the web container')
    .allowUnknownOption(true)
    .action(async (command: string[]) => {
      const ctx = detectProject()
      await dockerComposeExec(command, ctx.projectDir)
    })
}
```

`spree rails`, `spree bundle`, `spree migrate`, `spree routes`, `spree db:reset`, `spree db:console` follow the same pattern — ~15 lines each, no shared abstraction needed beyond `dockerComposeExec`.

### `spree console` becomes a thin wrapper

Drop `railsConsole` from `docker.ts` — `registerConsoleCommand` becomes:

```ts
await dockerComposeExec(['bin/rails', 'console'], ctx.projectDir)
```

Same for the other Rails-task-bound commands. `rakeTask` (the non-interactive variant that strips Spree boot noise) stays — `init`, `user create`, `api-key` still use it for parsed output.

### Registration

```diff
 // packages/cli/src/index.ts
+import { registerBuildCommand } from './commands/build.js'
+import { registerBundleCommand } from './commands/bundle.js'
+import { registerDbCommand } from './commands/db.js'
+import { registerExecCommand } from './commands/exec.js'
+import { registerGenerateCommand } from './commands/generate.js'
+import { registerMigrateCommand } from './commands/migrate.js'
+import { registerRailsCommand } from './commands/rails.js'
+import { registerRoutesCommand } from './commands/routes.js'
 // … existing registrations …
+registerExecCommand(program)
+registerRailsCommand(program)
+registerBundleCommand(program)
+registerGenerateCommand(program)
+registerMigrateCommand(program)
+registerBuildCommand(program)
+registerDbCommand(program)
+registerRoutesCommand(program)
```

### The Laravel Sail parallel

For reviewers benchmarking against Sail:

| Sail | This proposal |
|---|---|
| `sail artisan make:model Brand` | `spree generate model Brand` |
| `sail artisan migrate` | `spree migrate` |
| `sail composer require stripe/stripe-php` | `spree bundle add stripe` |
| `sail tinker` | `spree console` |
| `sail shell` | `spree exec bash` |
| `sail up -d` | `spree dev` |
| `sail build` | `spree build` |

Same shape: thin shell over `docker compose exec`, predictable verb-noun mapping, generic escape hatch covers the long tail.

---

## Track 2c — `spree upgrade` (scripted guidance, not magic)

### What it is and what it isn't

**Is:** an interactive walkthrough of the steps required to upgrade from your current Spree version to the target version, with the automatable parts (rake data tasks, `db:migrate`) offered as "run now? [Y/n]". Each step is named, ordered, idempotent, and re-runnable. Output mirrors what's in `docs/upgrades/<version>.mdx` so the command and the docs can never drift.

**Isn't:** a magic `spree upgrade && done` button. Upgrades involve `bundle update spree*`, schema migrations, data backfills, occasional config edits, and version-specific manual review steps (e.g. "audit your custom decorators against the renamed class"). A command that owns half the steps and silently hands the rest to the user is worse than no command — users assume it owned the whole thing and skip the manual parts. The framing is "scripted runbook," not "automation."

This is the same shape as Rails' own upgrade flow (`rails app:update` walks you through config diffs interactively) and Spree's existing per-task `desc` strings ("Run the full 5.4 → 5.5 channel upgrade"). It just makes them addressable from one command and sequences them correctly.

### The mapping problem and how it's solved

Today's data tasks are *implicitly* version-scoped — `spree/core/lib/tasks/channels.rake` is the 5.4→5.5 channel upgrade, `price_history.rake:seed` is the 5.4→5.5 EU Omnibus backfill — but only the rake `desc` strings encode that, and only as prose. The version → tasks mapping lives nowhere machine-readable. Adding `spree upgrade` requires a mapping.

The mapping uses **directory convention + tiny per-version manifest**, with the rake tasks themselves unchanged:

```text
core/lib/spree/upgrades/
├── 5_4_to_5_5/
│   ├── manifest.yml
│   └── README.md         (optional long-form; otherwise docs link)
├── 5_5_to_6_0/
│   ├── manifest.yml
│   └── README.md
└── …
```

`manifest.yml` per version is short and lists each step:

```yaml
# core/lib/spree/upgrades/5_4_to_5_5/manifest.yml
from: "5.4"
to: "5.5"
docs: "https://spreecommerce.org/docs/upgrades/5.5"

steps:
  - id: bundle
    name: "Update Spree gems"
    kind: shell
    command: "bundle update spree spree_api spree_admin"
    automated: true

  - id: migrate
    name: "Run database migrations"
    kind: rails
    command: "db:migrate"
    automated: true

  - id: channels
    name: "Create default channels and backfill product publications"
    kind: rake
    task: "spree:channels:full_upgrade"
    automated: true
    idempotent: true

  - id: price_history
    name: "Seed price history from current base prices (EU Omnibus)"
    kind: rake
    task: "spree:price_history:seed"
    automated: true
    idempotent: true
    skip_if: "non-EU stores can skip"

  - id: review_decorators
    name: "Review custom decorators against renamed Promotion → Discount API surface"
    kind: manual
    docs_anchor: "decorator-review"
    automated: false
```

Why a YAML manifest rather than a Ruby DSL or rake task metadata: the manifest is data the CLI reads — it does not need Rails booted to render the plan, and adding a step does not require touching CLI code. A new upgrade directory + manifest = a new upgrade. That's the whole extension model.

### CLI surface

```bash
spree upgrade                    # detect from → to from Gemfile.lock and run the manifest interactively
spree upgrade --to 5.5           # explicit target (when you want to step rather than jump)
spree upgrade --plan             # print the plan, don't execute (good for PR description / runbook)
spree upgrade --step price_history   # run one step idempotently
spree upgrade --from 5.4 --to 6.0    # multi-hop: walks 5.4→5.5, then 5.5→6.0 in sequence
```

`--from` defaults to the current installed Spree version (read from `Gemfile.lock` inside the container). `--to` defaults to the latest version with an upgrade manifest. The detected version pair selects which manifests to run, in order. For each step:

- `kind: shell` — print the command, ask, run via `dockerComposeExec`.
- `kind: rails` — same, run via `bin/rails <command>`.
- `kind: rake` — same, run via `bin/rake <task>`.
- `kind: manual` — print the description + docs link, wait for "done? [Y/n]" before continuing.

Default mode is interactive (each step asks). `--yes` runs all automated steps without prompting and stops at the first `kind: manual`. `--plan` doesn't execute anything.

### What this implies for rake task organization

The rake tasks themselves don't move. `spree/core/lib/tasks/channels.rake` stays where it is. What changes:

1. **Add per-version aggregator tasks** where they don't already exist. `channels.rake` already has `full_upgrade`; the pattern should be every version-scoped rake file ends with one idempotent aggregator task that runs the whole version's data migration for that domain. Then the manifest references just the aggregator, never the individual tasks.
2. **Tighten idempotency.** Aggregator tasks must be safe to re-run. Some of the existing ones already are (e.g. `create_defaults` uses `ensure_default_channel`); others (`backfill_*`) should be audited and made idempotent (skip rows where the target column is already populated, etc.) before they appear in any manifest.
3. **Manifest references task names, not file paths.** This makes the manifest survive rake task moves between files.

### What `spree upgrade` does NOT solve

- **Decorator and customization review.** A user with custom decorators on `Spree::Promotion` needs to manually audit them when the API surface renames to `Discount`. This is `kind: manual` in the manifest with a link to the upgrade doc. No tool can do this safely.
- **Database-specific gotchas.** `Spree::Current.store` and similar runtime-context migrations. Same answer: `kind: manual`, link to docs.
- **Cross-extension upgrades.** Each Spree extension owns its own upgrade docs and rake tasks. `spree upgrade` only walks core. Extensions can ship their own manifests under `<gem>/lib/spree/upgrades/`; the CLI globs the gem load paths to discover them. Out of scope for v1; document the convention but don't build it.

### Why not "spree upgrade just runs every rake task in a namespace"

The temptation: pattern-match `spree:upgrades:5_5:*` and run them all. Rejected because (a) ordering matters (you can't seed price history before the migration adds the table), (b) some steps aren't rake tasks (`bundle update`, manual reviews), (c) some are conditionally skippable, and (d) prose context per step matters for the user trusting the command. The manifest is the price of doing this honestly.

---

## Track 3 — `spree:api_resource` generator

### Goal

`spree generate api_resource Brand name:string:index slug:string:uniq` produces a complete, idiomatic v3 resource: model, migration, Store controller, Admin controller, two serializers, routes injected, request specs, OpenAPI fragment, and an admin-sdk type entry — all of it conformant with the conventions in `CLAUDE.md` (prefixed IDs, `{ data, meta }` envelope, flat params, Store vs Admin exposure rules).

### Why this lives in Ruby, not in the CLI

The CLI's `spree generate` proxies to `bin/rails g spree:<name>`. The actual scaffolding stays inside `core/lib/generators/spree/api_resource/` for the same reason `spree:model` lives there: generators belong with the framework they generate code for. The CLI's job is environment management; the generator's job is code generation. If we ever ship a non-Docker workflow (mise, native Ruby) the generator works unchanged.

### Generator surface

```text
spree:api_resource NAME [field[:type[:index|:uniq|:null|:default=…]]…] [options]
```

**Standard Rails field syntax**, extended with:

- `:uniq` — adds a unique index, validates uniqueness scoped to `spree_base_uniqueness_scope`
- `:index` — adds a non-unique index
- `:null` — marks `null: false` (the inverse of Rails' default; matches CLAUDE.md "always `null: false` on required columns")
- `belongs_to:<Model>` — adds the association + index, **no FK constraint** (per CLAUDE.md migration rules)

**Options:**

- `--id-prefix=brand` — optional, **auto-filled** from the class name when omitted. Default derivation: snake_case the class name and take the whole thing (`Brand → :brand`, `OrderRoutingRule → :order_routing_rule`). The generated `has_prefix_id :<prefix>` line is surfaced in the generator's summary output so the developer sees the chosen prefix and can edit the model file if they want a shorter or curated form. The existing codebase mixes both — some models go long (`:variant`, `:price`, `:invitation`), others go curated (`:ful` for Shipment, `:py` for Payment for Stripe parity, `:cf` for Metafield rename). Auto-fill picks the safe long form; edit afterwards if you want curated.
- `--store` / `--no-store` (default: yes — generate Store controller + serializer)
- `--admin` / `--no-admin` (default: yes)
- `--store-name=Discount` — emit Store controller/serializer/routes under a different external name (handles the Promotions/Discounts split)
- `--writable` (Store API) — opt into create/update/destroy on the Store controller (default: read-only, per CLAUDE.md "read-only by default")
- `--paranoid` — `acts_as_paranoid`, adds `deleted_at` column + `dependent: :destroy_async` on associations
- `--metafields` — include `Spree::Metafields` + `Spree::Metadata`
- `--skip-routes`, `--skip-openapi`, `--skip-specs` — escape hatches

### What it emits

For `spree generate api_resource Brand name:string:uniq active:boolean:default=true`:

```text
core/app/models/spree/brand.rb                          (owned-once)
core/db/migrate/<ts>_create_spree_brands.rb             (append-only)

api/app/controllers/spree/api/v3/store/brands_controller.rb        (managed)
api/app/controllers/spree/api/v3/admin/brands_controller.rb        (managed)
api/app/serializers/spree/api/v3/brand_serializer.rb               (managed)
api/app/serializers/spree/api/v3/admin/brand_serializer.rb         (managed)
api/spec/integration/api/v3/store/brands_spec.rb                   (managed)
api/spec/integration/api/v3/admin/brands_spec.rb                   (managed)
api/config/routes.rb                                                (route injected between markers)
core/lib/spree/testing_support/factories/brand_factory.rb          (managed)

docs/api-reference/store.yaml                                       (regenerate from specs)
packages/sdk/src/types/generated/store-brand.d.ts                   (regenerate via Typelizer)
packages/admin-sdk/src/types/generated/admin-brand.d.ts             (regenerate via Typelizer)
```

### Idempotency contract

Re-running the generator on an existing resource — the use case is "I added a field, regenerate" — should leave the model file untouched (it's the developer's now), append a new migration for the schema delta, and rewrite the serializers/controllers/specs/routes in place. The model file gets a header comment marking it as owned-once:

```ruby
# This file was scaffolded by `spree generate api_resource Brand`.
# It's yours now — behavior, validations, scopes, callbacks live here.
# Re-running the generator will NOT overwrite this file.
module Spree
  class Brand < Spree.base_class
    # ...
  end
end
```

The contract from the last-turn writeup (owned-once / managed-forever / append-only) is the whole trick. Hand-edit the model freely; hand-editing the serializer is allowed but means the next generator run will overwrite — which is fine because the conventions (prefixed IDs, typelize, what's Store vs Admin) are exactly what the generator already enforces.

**Route injection** uses Rails-style sentinel markers in `api/config/routes.rb`:

```ruby
namespace :store do
  # BEGIN spree:api_resource managed routes — do not hand-edit
  resources :brands, only: [:index, :show]
  # END spree:api_resource managed routes
end
```

`Thor::Actions#insert_into_file` finds the markers and inserts; if a `resources :brands` line already exists in the block, skip.

### Generated examples (abbreviated)

Model (owned-once, minimal — developer adds behavior). Note the `has_prefix_id :brand` line — prefixed IDs are computed on the fly via `Spree::PrefixedId` (no DB column), but the prefix must be declared per-model. The generator emits it from the `--id-prefix` flag:

```ruby
# backend/app/models/spree/brand.rb
# Owned-once: scaffolded by `spree generate api_resource Brand`.
module Spree
  class Brand < Spree.base_class
    include Spree::Metafields
    include Spree::Metadata

    has_prefix_id :brand          # from --id-prefix=brand; auto-derived from class name when flag omitted

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }

    self.whitelisted_ransackable_attributes = %w[name slug active]
  end
end
```

Migration (append-only, conventional Rails):

```ruby
class CreateSpreeBrands < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_brands do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :spree_brands, :slug, unique: true,
              name: 'index_spree_brands_on_slug'
  end
end
```

Store controller (managed):

```ruby
module Spree::Api::V3::Store
  class BrandsController < ResourceController
    protected

    def model_class
      Spree::Brand
    end

    def serializer_class
      Spree.api.brand_serializer
    end
  end
end
```

Store serializer (managed — no timestamps, customer-facing fields only):

```ruby
module Spree::Api::V3
  class BrandSerializer < BaseSerializer
    typelize active: :boolean
    attributes :id, :name, :slug, :active
  end
end
```

Admin serializer (managed — extends store, adds timestamps + back-office fields):

```ruby
module Spree::Api::V3::Admin
  class BrandSerializer < V3::BrandSerializer
    attributes :created_at, :updated_at
  end
end
```

Admin controller — empty subclass (full CRUD inherited from `Spree::Api::V3::Admin::ResourceController`).

Request spec (managed — single happy-path + a 422 case for OpenAPI examples; matches CLAUDE.md test guidance):

```ruby
# api/spec/integration/api/v3/store/brands_spec.rb
require 'swagger_helper'

RSpec.describe 'Brands API', type: :request do
  path '/api/v3/store/brands' do
    get 'List brands' do
      tags 'Brands'
      produces 'application/json'

      response '200', 'returns brands' do
        let!(:brand) { create(:brand) }
        run_test!
      end
    end
  end
end
```

(Admin spec covers create/update/destroy; same shape.)

### The `--store-name Discount` flag — the naming-split case

Models, tables, and ability checks stay `Brand` / `spree_brands` internally. The Store API surface re-exposes the same controller under a different external name:

```ruby
# api/config/routes.rb (Store namespace)
resources :discounts, controller: 'brands', only: [:index, :show]
```

…and the Store serializer is aliased (in the registry, not duplicated):

```ruby
Spree.api.brand_serializer = 'Spree::Api::V3::DiscountSerializer'
```

Generated `DiscountSerializer` is a one-line subclass of `BrandSerializer`. This is exactly the Promotions/Discounts pattern from the 6.0 plans — one flag, mechanical output, no per-resource thinking.

### Out of scope

- **TS frontend forms / pages.** Per the conversation: backend-only for now. `@spree/dashboard` route scaffolding is a separate generator, deferred.
- **Diffing across regenerations to produce migration deltas.** Migrations are generated once on resource create; field additions/changes are a separate `spree generate migration AddFieldToBrand` step (proxies to `bin/rails g migration`).
- **Decorator-aware generation** (i.e. detecting that the user has decorated `Spree::Brand` elsewhere). Decorators are last-resort per CLAUDE.md; we don't need to be clever about them.

---

## Track 4 — MCP tools + Skill (deferred)

The exact same `dockerComposeExec` + `spree:api_resource` engine surfaces three different ways:

1. **CLI** — what this doc specs.
2. **MCP tools** — `spree_generate_resource(name, fields, options)`, `spree_migrate()`, `spree_run_rails(args)`, etc. Each is a typed wrapper over the same engine. Already partially exists (`mcp__claude_ai_Spree_Commerce_Docs_MCP__*` ships docs search; we'd add an action server).
3. **Skill / `AGENTS.md`** — `docs/agents/spree-customization.md` teaches the agent: "for green-field resources call `spree_generate_resource`; for cross-cutting edits (add a field to an existing serializer, wire a filter into an existing endpoint, write a subscriber) read the file and edit it; the generator output is correct-by-construction so don't second-guess it."

This doc treats those as a follow-up because they all depend on Tracks 1–3 existing first. The shape of (4) doesn't change the design of (1–3) at all — it's pure orchestration over them.

---

## Sequencing

Strict order; each phase unblocks the next.

1. **Track 1 (compose rewrite + eject diff).** Single PR. Without this, every other track's wrappers still trigger rebuilds and the developer story is unchanged.
2. **Track 2a — passthrough (`spree exec`, `spree rails`, `spree bundle`).** Single PR. After this, every Rails command is reachable without docs.
3. **Track 2b — hot-path wrappers (`spree generate`, `spree migrate`, `spree build`, `spree db:console`, `spree rake`, `spree task`).** Single PR. Polishing; users have escape hatch from 2a if a wrapper is missing or buggy.
4. **Track 2c — `spree upgrade` + per-version manifests.** Separate PR. Starts with one manifest (5.4→5.5, since the rake tasks largely exist). Adding manifests for future versions becomes part of the release checklist. Can ship independent of Track 3.
5. **Track 3 — `spree:api_resource` generator.** Larger PR, lives in `core/`. The model + migration paths can ship before the serializer/controller/route paths if needed; the value is cumulative.
6. **Track 4 — MCP / skill.** Follow-up doc + PR. Not in this scope.

Devcontainer and mac perf docs (OrbStack, virtiofs) ride along with Track 1 as a separate `docs/developer/dev-environment.md` page.

---

## Resolved decisions

These were open and now aren't, written down so future-me doesn't reopen them:

1. **Compose profile vs file swap.** Keep the file swap; revisit only if it bites.
2. **`spree generate` does NOT auto-run `spree migrate`.** Two-step, like Rails. Documented in command help.
3. **Prefixed-ID prefix is per-model and auto-filled.** `Spree::PrefixedId` (`spree/core/app/models/concerns/spree/prefixed_id.rb`) computes IDs on the fly via Sqids from the integer PK — no column, no DB change. The prefix is declared per-class via `has_prefix_id :prod`. The generator auto-derives the prefix from the class name (`Brand → :brand`, `OrderRoutingRule → :order_routing_rule`) and emits the line, surfacing the chosen prefix in the summary output so the developer can edit if they want a shorter or curated form (e.g. matching Stripe like `:py`). See Track 3 options for the override flag.
6. **All upgrade rake tasks MUST be idempotent.** This is a hard contract, not a soft preference: a task that fails on re-run cannot ship to a manifest. The pattern is `where.not(<target_col>: nil)` skip-guards on `backfill_*` and `ensure_*`-style guards on `create_*` (as `channels.rake:create_defaults` does today via `ensure_default_channel`). Audit pass on existing tasks is a prerequisite for Track 2c.
7. **Extension manifests deferred.** v1 ships core-only. Extensions invoke their own upgrade rake tasks manually.

## Open questions

1. **~~`db/schema.rb` write permissions from the dev container.~~ Resolved.** Originally framed as a real problem — turns out it isn't. Every CLI command goes through `docker compose exec web …`, which means file writes happen as the container's default user (UID 1000, `rails`). On macOS, Docker Desktop and OrbStack do UID mapping at the VM boundary, so bind-mount writes always appear as the host user regardless of container UID. On Linux, the host user is typically UID 1000 (Ubuntu/Debian/Fedora default), so the UIDs match. The bundle/tmp/storage volumes are docker-managed (not bind-mounted), so the host never touches them — initial UID-1000 ownership inside the container is exactly what's wanted. The compose stays simple: no `user:` override, no init service, no entrypoint chown. The CLI exporting `HOST_UID`/`HOST_GID` is only needed for the Linux multi-user edge case (host user not UID 1000) and is deferred until someone actually hits it.

2. **`spree-starter` PR.** The new compose ships from `spree-starter`'s `backend/` template. A sibling PR lands the new `docker-compose.dev.yml` there. (The monorepo `server/` directory is dev-only for the gems and doesn't need separate consideration.)

3. **Idempotency helper for backfill tasks.** The existing `backfill_*` family will get `where.not(<col>: nil)` guards as part of the Track 2c prep audit. Whether to extract a shared helper (`Spree::Upgrades::Idempotent.backfill(scope, &block)`) or keep guards per-task is style preference; lean per-task — explicit skip conditions read better than a clever wrapper for something that runs once per upgrade.
