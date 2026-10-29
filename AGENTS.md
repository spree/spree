# Spree Commerce — Development Rules

Area rules live next to the code and load when you work there: `spree/AGENTS.md` (Ruby gems, APIs, RSpec), `packages/AGENTS.md` (TypeScript packages, dashboards, Playwright) and `docs/AGENTS.md` (documentation site). Anything not covered follows standard Ruby on Rails 8.1 and React / TanStack / Vite practice — these files only record what this codebase does differently or what has bitten us before.

## Plans

Feature plans live in `docs/plans/`, written from `docs/plans/_template.md` — never anywhere else. Before a significant architectural change, check existing plans for conflicts, including their "Constraints on Current Work" sections, which apply even when you aren't implementing that plan. Use `/create-plan`, `/update-plan`, and `/implement-plan <plan>` to deliver one end to end.

## Monorepo structure

| Directory | Contents |
| --- | --- |
| `spree/core` | `spree_core` — models, workflows, services, business logic |
| `spree/api` | `spree_api` — Store, Admin and Seller REST APIs (v3) |
| `spree/emails` | `spree_emails` (optional) — transactional emails; the default for installations without a storefront that sends its own |
| `spree/dashboard` | `spree_dashboard` (optional) — serves a built dashboard at `/dashboard` and seller panel at `/sellers` from the Rails node |
| `spree/mcp` | `spree_mcp` — MCP server for the back office, under the Admin API's tenancy and permission rules |
| `spree/opentelemetry` | `spree_opentelemetry` — distributed tracing |
| `spree/providers/*` | Provider gems with flat names: `spree_avalara` (tax), `spree_easypost` (rates, labels), `spree_meilisearch` (product search), `spree_stripe` (payments) |
| `packages/dashboard` | `@spree/dashboard` — React admin SPA: routes, schemas, resource hooks, locales |
| `packages/dashboard-core` | `@spree/dashboard-core` — framework and plugin API: registries, providers, shared hooks and components, admin SDK client |
| `packages/dashboard-ui` | `@spree/dashboard-ui` — design system (shadcn on Base UI); source-only, headless |
| `packages/seller-dashboard` | `@spree/seller-dashboard` — seller panel for marketplaces |
| `packages/dashboard-starter`, `packages/seller-dashboard-starter` | Thin host apps; canonical source of the public starter template repos and the in-repo test of the plugin pipeline |
| `packages/dashboard-plugin-example` | Reference dashboard plugin used by the plugin docs |
| `packages/sdk`, `admin-sdk`, `seller-sdk` | TypeScript clients for the Store, Admin and Seller APIs |
| `packages/core` | `@spree/core` — universal TypeScript with no HTTP: code lists, enums, money helpers, filter vocabulary |
| `packages/sdk-core` | Private shared HTTP, retry and error layer for the SDKs |
| `packages/cli`, `packages/create-spree-app` | `@spree/cli` and project scaffolding |
| `packages/docs` | `@spree/docs` — offline docs package for AI agents |
| `docs/` | Mintlify site deployed to spreecommerce.org/docs |
| `server/`, `storefront/` | Gitignored per-worktree clones of `spree/spree-starter` and `spree/storefront` |

## Development environment

Work happens in git worktrees managed by [worktrunk](https://worktrunk.dev) (`wt`). Each one gets its own `server/` (monorepo gems loaded as path gems), its own Postgres database copied from a seeded template, and stable https URLs through portless. The main checkout is for integration, not for running servers. Don't use the Docker-based `pnpm server:*` commands in worktrees.

```bash
wt switch -c feature-x   # new worktree + provisioned environment
pnpm wt:dev              # Rails → https://feature-x.spree.localhost
pnpm wt:dashboard        # admin → https://admin.feature-x.spree.localhost
pnpm wt:seller           # seller panel → https://sellers.feature-x.spree.localhost
pnpm wt:storefront       # Next.js storefront → https://store.feature-x.spree.localhost
pnpm wt:e2e [spec...]    # Playwright against this worktree
pnpm wt:template         # rebuild the template DB after schema-changing pulls
```

- Logins: admin `spree@example.com` / `spree123`; seller `seller@example.com` / `spree123` after `cd server && bin/rails spree:sellers:sample_data`.
- A new gem migration needs `cd server && bin/rails spree:install:migrations db:migrate`, then `pnpm wt:template`. Ruby under `app/` reloads per request; changes under a gem's `lib/` need a server restart.
- Emails land in Mailpit at <http://localhost:8025>.
- `storefront/` keeps its own `.git` — commit and push from inside it before `wt remove`. Never commit its `pnpm-lock.yaml` (it points at this worktree's SDK). Re-run `pnpm wt:storefront` to pick up SDK or serializer changes.
- **Never stop dev servers that are already running** unless they are broken.
- **Cloud sessions** (`CLAUDE_CODE_REMOTE=true`) have no worktrees or portless: start servers with `scripts/cloud/start.sh [rails|dashboard|seller|all]` and check UI changes with `node scripts/cloud/screenshot.mjs <url> <out.png> --login`.

## General rules

- Write to humans in plain, precise English — no jargon or abbreviations, short sentences, lists over walls of text.
- Comment only non-obvious code. No comments on removed code, framework-native calls, shapes or serializers. Docs explain what and why, never internal how.
- Reuse before you add: search for an existing helper, component or concern first. Fewer lines is the goal.
- Assume hostile input: validate, scope every lookup to the tenant, never trust client-supplied types or ids.
- The admin dashboard is the reference implementation. Seller panel features reuse its code by moving shared pieces into `dashboard-core` / `dashboard-ui`.

## API contract (applies to Ruby, SDKs and dashboards alike)

- **Prefixed IDs** (`prod_86Rf07xd4z`) in every request, response and event payload — never raw integer ids. IDs are strings; never cast them to integers.
- **No Ruby class names on the wire** — not in requests, responses, filters, webhooks, permission subjects, SDK types or docs. Use the short `api_type` name (`Spree::PriceRules::VolumeRule` → `volume_rule`). Details in `spree/AGENTS.md`.
- **Read and write names match.** A field a serializer exposes is accepted under the same name on write; legacy column names are bridged on the model, never by the client.
- **Deprecate, never remove.** Store, Admin and Seller APIs are stable contracts: a renamed field keeps working, marked `deprecated:`, until the next minor release, and the upgrade guide names its replacement. Ruby renames keep the old name working for one release with a deprecation warning.
- **Money is never a float**, in Ruby or TypeScript (`docs/plans/6.0-money-correctness.md`).
- **One store per installation.** Store-owned data belongs to a store; cross-store sharing is gone.

## Git

- Never commit to `main`. Branches start with `feat/`, `fix/` or `chore/`; bug-fix commits start with `Fix: `.
- Titles use plain verbs (Added, Removed, Fixed, Changed). Bodies are three or four sentences on what and why.
- No co-author or "generated with" trailers.
- Pull request descriptions are public: no credentials, personal data or local URLs. Keep them short; bullets for larger changes.

## Testing

Many sessions share this machine. Every Ruby test run goes through `scripts/test/` — **never a bare `parallel_rspec`** (a hook blocks it):

```bash
pnpm test:changed                     # specs covering this branch's changes — run before pushing
pnpm test:changed -- --list           # what would run, and which changes have no spec
pnpm test:rspec core spec/models/spree/state_spec.rb:7   # targeted run in one engine
pnpm test:rspec api                   # a full engine suite (queued machine-wide)
```

The full suite is CI's job: push and watch `gh pr checks --watch`. Run a full suite locally only to reproduce a CI failure, or when a change touches everything (a factory, a migration, `Spree::Base`). Engines: `core`, `api`, `emails`, `dashboard`, `opentelemetry`, `avalara`, `easypost`, `meilisearch`, `stripe`.

Every behaviour change a merchant or seller can see — including a backend-only validation or status rule — ships with a Playwright spec (see `packages/AGENTS.md`).
