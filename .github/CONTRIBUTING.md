# Contributing

Thank you for your interest in contributing to Spree! This guide will help you get started.

Please read our [Code of Conduct](../CODE_OF_CONDUCT.md) before contributing.

## Table of Contents

- [Getting Started](#getting-started)
  - [Cloning the repository](#cloning-the-repository)
  - [Spree codebase](#spree-codebase)
- [Backend Development (Ruby)](#backend-development-ruby)
  - [Engines overview](#engines-overview)
  - [Spree namespace](#spree-namespace)
  - [Setup](#setup)
  - [Running engine tests](#running-engine-tests)
  - [Running tests in parallel](#running-tests-in-parallel)
  - [Integration tests (Admin Panel)](#integration-tests-admin-panel)
  - [Performance in development mode](#performance-in-development-mode)
- [TypeScript Development](#typescript-development)
  - [Setup](#setup-1)
  - [Packages](#packages)
  - [Common commands](#common-commands)
  - [Package-specific commands](#package-specific-commands)
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

### Spree codebase

Spree is a monorepo with three main areas:

- **`spree/`** — Ruby gems (core, api, admin, emails) distributed as separate packages via RubyGems
- **`packages/`** — TypeScript packages (SDK, Next.js helpers)
- **`server/`** — A Rails application cloned from [spree-starter](https://github.com/spree/spree-starter) that mounts the Spree gems (not checked in — run `pnpm server:setup` to create it)

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

### Setup

The server app is not checked into the monorepo. It's cloned from [spree-starter](https://github.com/spree/spree-starter) on first setup, with `SPREE_PATH=..` automatically configured so it uses your local Spree gems.

**Step 1: Start infrastructure**

```bash
docker compose up -d     # starts Postgres, Redis, Meilisearch
```

Or install PostgreSQL and Redis locally if you prefer.

**Step 2: Clone the server app**

```bash
pnpm server:setup
```

This clones [spree-starter](https://github.com/spree/spree-starter) into `server/` and sets `SPREE_PATH=..` in `server/.env` so it uses your local Spree gems.

**Step 3: Configure and run**

```bash
cd server
# Edit .env if needed (e.g. DATABASE_USERNAME, DATABASE_HOST, DATABASE_PORT)
bin/setup        # installs Ruby (via mise), system packages, gems, prepares database
bin/dev          # starts Rails + Sidekiq + CSS watchers via overmind
```

Use `bin/setup --reset` to drop and recreate the database.

The app runs at [http://localhost:3000](http://localhost:3000). Admin Panel is at [http://localhost:3000/admin](http://localhost:3000/admin).

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

### Integration tests (Admin Panel)

The Admin Panel uses feature specs that run in a real browser via chromedriver. You only need this if you're working on admin UI changes.

Install chromedriver on macOS:

```bash
brew install chromedriver
```

### Performance in development mode

You may notice that your Spree store runs slower in development environment. This is caused by disabled caching and automatic reloading of code after each change.

Caching is disabled by default. To turn on caching please run:

```bash
cd server && bin/rails dev:cache
```

You will need to restart rails server after this change.

## TypeScript Development

### Setup

TypeScript developers don't need Ruby installed. Docker Compose from the repository root starts the backend using a prebuilt image:

```bash
docker compose up -d
```

This boots PostgreSQL, Redis, Meilisearch, and the Spree backend automatically (no `pnpm server:setup` needed). The API is available at `http://localhost:3000`.

Then install dependencies and start all packages in watch mode:

```bash
pnpm install
pnpm dev
```

### Packages

| Package | Path | Description |
|---|---|---|
| `@spree/sdk` | `packages/sdk` | TypeScript SDK for the Spree Storefront API |

### Common commands

Run from the repository root — [Turborepo](https://turbo.build/) orchestrates tasks across all packages:

| Command | Description |
|---|---|
| `pnpm dev` | Start Docker backend + watch mode for all packages |
| `pnpm build` | Build all packages (SDK first, then Next.js) |
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

### Type generation

TypeScript types in `packages/sdk/src/types/generated/` are auto-generated from the Rails API serializers using [typelizer](https://github.com/skryukov/typelizer). To regenerate after changing serializers:

```bash
cd spree/api
mise install --yes # to install Ruby if you don't have it already
bundle install # to install dependencies
bundle exec rake typelizer:generate
```

After regenerating types, update the Zod schemas:

```bash
pnpm --filter @spree/sdk generate:zod
```

### Releasing packages

Packages use [Changesets](https://github.com/changesets/changesets) for version management:

```bash
pnpm changeset
```

This creates a changeset file describing your changes. Commit it with your PR. When merged to `main`, a GitHub Action creates a "Version Packages" PR that bumps the version and publishes to npm.

## Code Style

Consistent code style is enforced via automated linters. Please make sure your changes pass linting before submitting a PR.

**Ruby:** We use [RuboCop](https://rubocop.org/) for Ruby code. Configuration lives in `server/.rubocop.yml`. Run it from the `server/` directory:

```bash
cd server
bundle exec rubocop
```

To auto-fix correctable offenses:

```bash
bundle exec rubocop -a
```

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
- **Include a changeset** (TypeScript packages only). Run `pnpm changeset` if your change affects `@spree/sdk`.
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

Spree comes with an [AGENTS.md](../../../AGENTS.md) file that instructs coding agents like Claude Code or Codex to help you with your development.

We also have an MCP server built on top of our Documentation website to help you with your development.

Add this URL to your AI tools:

```
https://spreecommerce.org/docs/mcp
```

In Claude Code you need to go to [Connectors](https://claude.ai/settings/connectors) settings and add the URL.

## That's a wrap!

Thank you for participating in Open Source and improving Spree - you're awesome!
