# Contributing

Thank you for your interest in contributing to Spree! This guide will help you get started.

Please read our [Code of Conduct](../CODE_OF_CONDUCT.md) before contributing.

## Table of Contents

- [Getting Started](#getting-started)
  - [Cloning the repository](#cloning-the-repository)
  - [Prerequisites](#prerequisites)
  - [Spree codebase](#spree-codebase)
  - [Setup](#setup)
  - [Running a backend day-to-day](#running-a-backend-day-to-day)
  - [Native Ruby (advanced)](#native-ruby-advanced)
- [Backend Development (Ruby)](#backend-development-ruby)
  - [Engines overview](#engines-overview)
  - [Spree namespace](#spree-namespace)
  - [Running engine tests](#running-engine-tests)
  - [Running tests in parallel](#running-tests-in-parallel)
  - [Integration tests (legacy Rails admin)](#integration-tests-legacy-rails-admin)
  - [Performance in development mode](#performance-in-development-mode)
- [TypeScript Development](#typescript-development)
  - [Packages](#packages)
  - [Common commands](#common-commands)
  - [Package-specific commands](#package-specific-commands)
  - [Working on the React dashboard](#working-on-the-react-dashboard)
  - [Dashboard E2E tests](#dashboard-e2e-tests)
  - [Type generation](#type-generation)
  - [Releasing packages](#releasing-packages)
- [Code Style](#code-style)
- [Making Changes](#making-changes)
  - [Branch naming](#branch-naming)
  - [Commit messages](#commit-messages)
- [Submitting Changes](#submitting-changes)
  - [Pull request guidelines](#pull-request-guidelines)
- [Reporting Bugs](#reporting-bugs)
- [Using AI Tools for Development](#using-ai-tools-for-development)

## Getting Started

### Cloning the repository

Spree is a big monorepo. For a faster clone, use a **partial clone** which downloads file contents on demand while keeping full commit history for `git log` and `git blame`:

```bash
git clone --filter=blob:none https://github.com/spree/spree.git
```

### Prerequisites

You need **Node.js 20+** to run the workspace scripts (including `pnpm server:setup`, which both backend and TypeScript contributors use). Install it via [nvm](https://github.com/nvm-sh/nvm), [mise](https://mise.jdx.dev), [fnm](https://github.com/Schniz/fnm), or your package manager (`brew install node` on macOS).

`pnpm` is provisioned automatically via [Corepack](https://nodejs.org/api/corepack.html) (bundled with Node) — the repository pins its version in `package.json`, and the first `pnpm` command will fetch the matching release. If Corepack is disabled in your environment, run `corepack enable` once.

### Spree codebase

Spree is a monorepo with three main areas:

- **`spree/`** — Ruby gems (core, api, admin, emails) distributed as separate packages via RubyGems
- **`packages/`** — TypeScript packages (SDKs, CLI, project scaffolding, docs, React dashboard)
- **`server/`** — A Rails application cloned from [spree-starter](https://github.com/spree/spree-starter) that mounts the local Spree gems (not checked in — `pnpm server:setup` creates it)

### Setup

A single command bootstraps the whole monorepo for both backend and frontend work. You need **Docker** running locally (Docker Desktop, OrbStack, or any compatible runtime) — no Ruby, Postgres, or Redis on your host.

```bash
pnpm install        # workspace dependencies
pnpm server:setup   # ~5–10 min on first run; idempotent
```

`pnpm server:setup` clones [spree-starter](https://github.com/spree/spree-starter) into `./server/`, wires it to load Spree gems from the monorepo via a Docker compose overlay, builds the dev image, starts the stack (Postgres + Redis + Meilisearch + Rails `web` + Sidekiq `worker`), and prepares the database. The full sequence lives in `scripts/server-setup.sh`.

When it's done, the backend is up at [http://localhost:3000](http://localhost:3000) and the admin is at [http://localhost:3000/admin](http://localhost:3000/admin). Sign in with the seed admin: **`spree@example.com`** / **`spree123`** (override at seed time with `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars — see `spree/core/app/services/spree/seeds/admin_user.rb`).

Optionally load sample products, taxonomies, and option types:

```bash
pnpm server:load_sample_data
```

### Running a backend day-to-day

After the one-time setup, use these to bring the stack up and down:

```bash
pnpm server:dev     # run the stack in the foreground — streams web + worker logs, Ctrl+C stops them
pnpm server:stop    # full teardown (also stops postgres / redis / meilisearch)
pnpm server:restart # restart web + worker in place
pnpm server:logs    # follow web container logs (when the stack runs detached)
pnpm server:console # open a Rails console inside the container
pnpm server:seed    # re-run database seeds
pnpm server:build   # rebuild the dev image (only after Dockerfile / .ruby-version changes)
```

`server:dev` behaves like any TS dev server (`vite dev`, the dashboard's `pnpm dev`): it runs in the foreground and Ctrl+C stops the app containers. Postgres, Redis, and Meilisearch keep running for a fast next boot — `pnpm server:stop` shuts everything down.

Run any CLI command against the running backend from `server/`:

```bash
cd server
pnpm exec spree migrate
pnpm exec spree generate model Brand name:string
pnpm exec spree upgrade --plan
```

See the [`@spree/cli` README](../packages/cli/README.md) for the full command surface.

Which command after which change:

| What changed | What to run |
|---|---|
| Ruby code in `spree/*` gems | Nothing — gems are bind-mounted; code reloads on the next request |
| A new migration in a gem | Nothing — the next `pnpm server:dev` boot applies it (or `cd server && pnpm exec spree migrate` while the stack runs) |
| Gem dependencies (gemspec / Gemfile / lock drift after `git pull`) | Nothing — the next `pnpm server:dev` boot self-heals via `bundle check || bundle install` (or `cd server && pnpm exec spree bundle install` while the stack runs) |
| Compose files / `server/.env` | `pnpm server:dev` (force-recreates the containers) |
| `server/Dockerfile` / `.ruby-version` / starter update that breaks the image build ("lockfile can't be updated because frozen") | `pnpm server:build`, then `pnpm server:dev` — the build script handles the edge-rewritten `Gemfile.lock` automatically |
| Meilisearch image bump ("database version … is incompatible") | Remove the `server_meilisearch_data` volume, boot, then reindex (`pnpm exec spree rake spree:search:reindex`) — the index is derived data |
| Broken beyond repair | `pnpm server:setup` (full reset — wipes the database and volumes) |

Re-run `pnpm server:setup` **only** to fully reset — it does `docker compose down -v` + `rm -rf ./server`, wiping all DB data.

### Native Ruby (advanced)

If you prefer the fastest possible inner loop and don't mind installing Ruby, Postgres, Redis, and Meilisearch on your host directly, you can skip Docker:

```bash
pnpm server:create   # clones spree-starter, writes server/.env with SPREE_PATH=..
cd server
bin/setup            # installs Ruby (via mise), Postgres/Redis/Meilisearch (via brew bundle on macOS), gems, prepares the database
bin/dev              # starts Rails + Sidekiq + CSS watchers via Foreman
```

This path is faster per request but means more on your host. It also runs against your installed system services, not a sandboxed Docker stack.

## Backend Development (Ruby)

### Engines overview

The Spree [Rails engines](https://guides.rubyonrails.org/engines.html) live inside `spree/` and are distributed as separate gems (Ruby packages installed via Bundler):

| Engine | Gem | Description |
|---|---|---|
| `core` | `spree_core` | Models, services, business logic |
| `api` | `spree_api` | REST APIs |
| `admin` | `spree_admin` | Admin dashboard |
| `emails` | `spree_emails` | Transactional emails |

### Spree namespace

All Spree models, controllers and other Ruby classes are namespaced by the `Spree` keyword, eg. `Spree::Product`. This means that those files are also located in `spree` sub-directories eg. [app/models/spree/product.rb](https://github.com/spree/spree/blob/main/spree/core/app/models/spree/product.rb).

### Running engine tests

Each engine has its own test suite. First install the shared dependencies at the `spree/` level, then navigate into the specific engine to set up and run its tests:

```bash
# 1. Install shared dependencies
cd spree
bundle install

# 2. Set up and run tests for a specific engine (e.g. core)
cd core
bundle install
bundle exec rake test_app
bundle exec rspec
```

Replace `core` with `api`, `admin`, or `emails` to test other engines.

By default engine tests run against SQLite3. To run against PostgreSQL, set the `DB` environment variable:

```bash
DB=postgres DB_USERNAME=postgres DB_PASSWORD=password DB_HOST=localhost bundle exec rake test_app
```

Run a single spec file:

```bash
cd spree/core
bundle exec rspec spec/models/spree/state_spec.rb
```

Run a specific test by line number:

```bash
cd spree/core
bundle exec rspec spec/models/spree/state_spec.rb:7
```

### Running tests in parallel

For faster test runs on multi-core machines, you can use the `parallel_tests` gem to distribute spec files across multiple CPU cores.

After setting up the test app, create databases for parallel workers:

```bash
cd spree/core
bundle exec rake parallel_setup
```

Then run specs in parallel:

```bash
bundle exec parallel_rspec spec
```

You can also specify the number of workers:

```bash
bundle exec rake "parallel_setup[4]"
bundle exec parallel_rspec -n 4 spec
```

After schema changes, re-run `bundle exec rake parallel_setup` to update the worker databases.

### Integration tests (legacy Rails admin)

The legacy Rails admin (`spree/admin`) ships feature specs that run in a real browser via chromedriver. You only need this if you're touching the legacy admin UI.

Install chromedriver on macOS:

```bash
brew install chromedriver
```

The 6.0 React dashboard (`packages/dashboard`) has its own end-to-end test suite running on Playwright against a real Rails backend — see [Dashboard E2E tests](#dashboard-e2e-tests) under TypeScript Development.

### Performance in development mode

Spree runs slower in development because caching is disabled and code reloads on each request. To turn on caching:

```bash
cd server && pnpm exec spree rails dev:cache
```

Restart the Rails server after running this (Ctrl+C the running `pnpm server:dev` and start it again).

## TypeScript Development

The backend setup is the same as for Ruby work — see [Setup](#setup) above. With `pnpm server:setup` done, the Rails backend is running and you can start the packages you want to work on.

### Packages

| Package | Path | Published | Description |
|---|---|---|---|
| `@spree/sdk` | `packages/sdk` | yes | TypeScript SDK for the Spree Store API |
| `@spree/admin-sdk` | `packages/admin-sdk` | yes | TypeScript SDK for the Spree Admin API |
| `@spree/cli` | `packages/cli` | yes | CLI for managing Spree Commerce projects |
| `create-spree-app` | `packages/create-spree-app` | yes | Project scaffolding (`npm create spree-app`) |
| `@spree/docs` | `packages/docs` | yes | Developer documentation for AI agents and local reference |
| `@spree/dashboard` | `packages/dashboard` | no | React SPA admin dashboard (Spree 6.0, replaces the legacy Rails admin) |
| `@spree/dashboard-core` | `packages/dashboard-core` | no | Framework: registries, providers, generic infra hooks for the dashboard |
| `@spree/dashboard-ui` | `packages/dashboard-ui` | no | Design system used by the dashboard |
| `@spree/sdk-core` | `packages/sdk-core` | no | Shared HTTP/retry/error layer used by both SDKs |

### Common commands

Run from the repository root — [Turborepo](https://turbo.build/) orchestrates tasks across all packages:

| Command | Description |
|---|---|
| `pnpm dev` | Watch mode for all packages (does not boot the backend — use `pnpm server:dev` for that) |
| `pnpm build` | Build all packages (Turbo resolves dependency order) |
| `pnpm test` | Run tests in all packages |
| `pnpm lint` | Lint all packages |
| `pnpm typecheck` | Type-check all packages |
| `pnpm clean` | Remove build artifacts |

### Package-specific commands

You can also run commands in a single package:

```bash
pnpm --filter @spree/sdk test:watch
pnpm --filter @spree/sdk console
pnpm --filter @spree/sdk generate:zod
```

Tests use [Vitest](https://vitest.dev/) with [MSW](https://mswjs.io/) for API mocking at the network level.

### Working on the React dashboard

The dashboard runs as a Vite dev server (port 5173) that proxies `/api/*` to the Rails backend on port 3000 — required for the auth refresh cookie to work over plain HTTP.

```bash
# Terminal 1: backend
pnpm server:dev

# Terminal 2: dashboard
cd packages/dashboard
pnpm dev   # http://localhost:5173
```

Sign in with `spree@example.com` / `spree123`. To point at a non-default backend, set `VITE_SPREE_API_URL` (also needs to be set at build time for production bundles, not just dev):

```bash
VITE_SPREE_API_URL=https://my-spree.example.com pnpm dev
```

**Gotcha:** the dashboard imports `@spree/admin-sdk` from its **built** `dist/`, not source. If you edit `admin-sdk` (or `sdk-core`, or `sdk`) and want the dashboard to see the changes, run `pnpm build` from the monorepo root first (Turbo-cached). Editing dashboard code alone doesn't need this.

See `packages/dashboard/README.md` for the full architecture (auth, permissions, extension points, the three-package split between `dashboard`, `dashboard-core`, and `dashboard-ui`).

### Dashboard E2E tests

The React dashboard ships an end-to-end suite running on [Playwright](https://playwright.dev/) against a real Rails backend — no mocks. The spec files exercise the full UI: login, staff invitation, invitee signup. CI runs the same suite via the `dashboard-e2e` job in `.github/workflows/packages.yml`.

To run locally you need Ruby (the suite boots a real Rails server) and a one-time browser install:

```bash
# Make sure the dummy Rails app exists (one-time, after a fresh checkout).
cd spree/api
bundle install
bundle exec rake test_app

# Install Playwright's Chromium (one-time per machine).
cd ../../packages/dashboard
pnpm test:e2e:install

# Run the suite. Boots Rails on :3010 + Vite on :5174, runs all specs, tears
# both down. Safe to re-run repeatedly — the SQLite DB resets each run.
pnpm test:e2e
```

For interactive debugging (time-travel through actions, inspect the DOM at each step):

```bash
pnpm test:e2e:ui
```

Filter to a single spec or test name:

```bash
pnpm test:e2e e2e/auth.spec.ts
pnpm test:e2e -g "invites a teammate"
```

When a test fails, Playwright drops a screenshot, video, and DOM snapshot in `packages/dashboard/test-results/<spec>/` — usually enough to diagnose without re-running.

### Type generation

TypeScript types in `packages/sdk/src/types/generated/` (Store API) and `packages/admin-sdk/src/types/generated/` (Admin API) are auto-generated from the Rails serializers using [typelizer](https://github.com/skryukov/typelizer). Zod schemas in `packages/sdk/src/zod/generated/` are derived from the TS types.

A **Lefthook pre-commit hook** regenerates both whenever you commit a change to `spree/api/app/serializers/**/*.rb` and re-stages the generated output. You don't need to run anything manually for the common case.

To regenerate manually (useful when iterating on serializers before committing):

```bash
cd server
pnpm exec spree rake typelizer:generate     # regenerate TS types
cd ../packages/sdk
pnpm generate:zod                            # regenerate Zod schemas
```

If you'd rather avoid the Docker round-trip and have Ruby on your host, the native equivalent works too:

```bash
cd spree/api
bundle install
bundle exec rake typelizer:generate
```

### Releasing packages

Published packages use [Changesets](https://github.com/changesets/changesets) for version management. Each package owns its own `.changeset/` folder, so changesets must be created from inside the package directory:

```bash
cd packages/sdk    # or packages/admin-sdk, packages/cli, packages/create-spree-app
pnpm changeset
```

This creates a changeset file describing your changes. Commit it with your PR.

Releasing is a two-step flow: a maintainer consumes the pending changesets (`changeset version` — writes the CHANGELOG and bumps `package.json`) and merges that bump to `main`; the release jobs in `.github/workflows/packages.yml` then detect the unpublished version and publish with npm provenance via Trusted Publishing. `@spree/admin-sdk` publishes under the `next` dist-tag while on the 0.x Developer Preview line; the others ship as `latest` (prereleases go to `beta`).

Private packages (`@spree/dashboard`, `@spree/dashboard-core`, `@spree/dashboard-ui`, `@spree/sdk-core`) don't need changesets.

## Code Style

Consistent code style is enforced via automated linters. Please make sure your changes pass linting before submitting a PR.

**Ruby:** We use [RuboCop](https://rubocop.org/) for Ruby code. The configuration lives in `server/.rubocop.yml` and is shipped with [spree-starter](https://github.com/spree/spree-starter), so it's only available after running `pnpm server:setup`. Run it inside the container via the CLI:

```bash
cd server
pnpm exec spree exec bundle exec rubocop
```

To auto-fix correctable offenses:

```bash
pnpm exec spree exec bundle exec rubocop -a
```

(On the native path, drop the `pnpm exec spree exec` prefix and run `bundle exec rubocop` directly.)

**TypeScript:** We use [Biome](https://biomejs.dev/) for linting and formatting TypeScript code. Run it from the repository root:

```bash
pnpm lint
```

## Making Changes

### Branch naming

Create a new branch for your changes. Do not push changes to the main branch. Branch names should be human-readable and informative:

- Bug fixes: `fix/order-recalculation-total-bug`
- Features: `feature/my-new-amazing-feature`

### Commit messages

Keep your commit history meaningful and clear. Each commit should represent a logical unit of work. [This guide](https://about.gitlab.com/blog/2018/06/07/keeping-git-commit-history-clean/) covers this well.

A few tips:

- Write commit messages in the imperative mood (e.g. "Add feature" not "Added feature")
- Keep the first line under 72 characters
- If your change references a GitHub issue, include `Fixes #<number>` in the commit message or PR description to auto-close it on merge

## Submitting Changes

We use [GitHub Actions](https://github.com/spree/spree/actions) to run CI.

1. Push your changes to a topic branch in your fork of the repository.

    ```bash
    git push origin fix/order-recalculation-total-bug
    ```

2. [Create a Pull Request](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork) against the `main` branch.

3. Wait for CI to pass.

4. Wait for Spree Core team code review. We aim to review and leave feedback as soon as possible.

### Pull request guidelines

To help us review your PR quickly:

- **Keep PRs focused.** One feature or fix per PR. Smaller PRs are easier to review and merge.
- **Describe your changes.** Explain what you changed and why. Include screenshots for UI changes.
- **Add tests.** All new features and bug fixes should include appropriate test coverage.
- **Update documentation.** If your change affects user-facing behavior, update the relevant docs.
- **Include a changeset** if your change affects a published TypeScript package (`@spree/sdk`, `@spree/admin-sdk`, `@spree/cli`, or `create-spree-app`). Run `pnpm changeset` from inside that package's directory — each package owns its own `.changeset/` folder.
- **Ensure CI passes.** PRs with failing CI will not be reviewed.

## Reporting Bugs

We use [GitHub Issues](https://github.com/spree/spree/issues) to track bugs. Before filing a new issue, please search existing issues to avoid duplicates.

When reporting a bug, please include:

- **Spree version** you're using
- **Steps to reproduce** the problem
- **Expected behavior** vs **actual behavior**
- **Relevant logs or stack traces** (formatted with triple backticks)
- **Your environment** (Ruby version, database, OS)

We have an [issue template](.github/ISSUE_TEMPLATE.md) that will guide you through this.

Issues that are open for 14 days without actionable information or activity will be marked as stale and then closed. They can be re-opened if the requested information is provided.

## Using AI Tools for Development

Spree comes with an [AGENTS.md](../AGENTS.md) file that instructs coding agents like Claude Code or Codex to help you with your development.

We also ship [agent skills](https://spreecommerce.org/docs/developer/agentic/agent-skills) (`npx skills add spree/agent-skills`), a [docs MCP server](https://spreecommerce.org/docs/developer/agentic/mcp), and [LLM-ready documentation](https://spreecommerce.org/docs/developer/agentic/llm-docs) — see the [Agentic Development docs](https://spreecommerce.org/docs/developer/agentic/overview) for setup across Claude Code, Cursor, Copilot, and other tools.

The MCP server URL for quick setup:

```
https://spreecommerce.org/docs/mcp
```

## That's a wrap!

Thank you for participating in Open Source and improving Spree - you're awesome!
