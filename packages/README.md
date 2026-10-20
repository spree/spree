# Spree TypeScript Packages

This directory contains the TypeScript side of the Spree monorepo: the shared core library, the SDKs, the admin dashboard and seller panel, the CLI, project scaffolding, and the docs bundle. Everything here is managed with **pnpm workspaces** + **Turbo**, built with **tsup** (or Vite for the admin SPA), tested with **Vitest**, and linted with **Biome**. Versioning for published packages is handled by **Changesets**.

For monorepo-wide conventions (type generation pipeline, code style, testing) see the root [`CLAUDE.md`](../CLAUDE.md). For backend conventions see [`spree/`](../spree/).

## Status legend

| Badge | Meaning |
| --- | --- |
| **Stable** | Published to npm under `latest`, follows semver, safe for production. |
| **Release Candidate** | The Spree 6.0 line, published under the `beta` dist-tag. The API is settling; pin exact versions. |
| **Developer Preview** | Published to npm (0.x, under the `next` dist-tag); the API may change between minor versions. Pin exact versions. |
| **Internal** | Private to the workspace (`"private": true`), not published. |

## Packages

| Package | npm | Status | Description |
| --- | --- | --- | --- |
| [`sdk`](./sdk) | [`@spree/sdk`](https://www.npmjs.com/package/@spree/sdk) | **Stable** (1.x) · **Release Candidate** (2.0) | TypeScript client for the customer-facing **Store API v3**. 1.x targets Spree 5.x; 2.0 targets Spree 6.0. |
| [`admin-sdk`](./admin-sdk) | [`@spree/admin-sdk`](https://www.npmjs.com/package/@spree/admin-sdk) | **Release Candidate** (1.0) | TypeScript client for the **Admin API v3**. |
| [`seller-sdk`](./seller-sdk) | [`@spree/seller-sdk`](https://www.npmjs.com/package/@spree/seller-sdk) | **Release Candidate** (1.0) | TypeScript client for the **Seller API**, used by marketplace seller panels. |
| [`core`](./core) | [`@spree/core`](https://www.npmjs.com/package/@spree/core) | **Developer Preview** (0.x) | Universal code with no HTTP: country, currency, locale and unit code lists, exact money arithmetic, the filter vocabulary. |
| [`sdk-core`](./sdk-core) | — | **Internal** | Shared HTTP, retry and error layer the SDKs bundle. |
| [`dashboard`](./dashboard) | [`@spree/dashboard`](https://www.npmjs.com/package/@spree/dashboard) | **Release Candidate** (1.0) | The Spree 6.0 admin dashboard, a React single-page app. Replaces the legacy Rails `spree/admin` engine. |
| [`dashboard-core`](./dashboard-core) | [`@spree/dashboard-core`](https://www.npmjs.com/package/@spree/dashboard-core) | **Release Candidate** (1.0) | Dashboard framework: registries (table, nav, slot, settings-nav), providers, shared hooks, `defineDashboardPlugin`. The extension API. |
| [`dashboard-ui`](./dashboard-ui) | [`@spree/dashboard-ui`](https://www.npmjs.com/package/@spree/dashboard-ui) | **Release Candidate** (1.0) | Design system: shadcn primitives, headless composed components, design tokens. Source-only. |
| [`seller-dashboard`](./seller-dashboard) | [`@spree/seller-dashboard`](https://www.npmjs.com/package/@spree/seller-dashboard) | **Release Candidate** (1.0) | The marketplace seller panel, the seller-facing counterpart to the admin dashboard. |
| [`dashboard-starter`](./dashboard-starter) | — | **Internal** | Host app for the admin dashboard; the source of the [`spree/dashboard-starter`](https://github.com/spree/dashboard-starter) template. |
| [`seller-dashboard-starter`](./seller-dashboard-starter) | — | **Internal** | Host app for the seller panel; the source of the [`spree/seller-dashboard-starter`](https://github.com/spree/seller-dashboard-starter) template. |
| [`dashboard-plugin-example`](./dashboard-plugin-example) | — | **Internal** | Example dashboard plugin (a Brands feature); the reference for the plugin authoring docs. |
| [`cli`](./cli) | [`@spree/cli`](https://www.npmjs.com/package/@spree/cli) | **Stable** (3.x) | CLI for managing Spree projects scaffolded with `create-spree-app`. |
| [`create-spree-app`](./create-spree-app) | [`create-spree-app`](https://www.npmjs.com/package/create-spree-app) | **Stable** (2.x) | One-shot scaffolder: `npx create-spree-app my-store`. Sets up the backend and, optionally, the Next.js storefront. |
| [`docs`](./docs) | [`@spree/docs`](https://www.npmjs.com/package/@spree/docs) | **Developer Preview** (0.x) | Spree developer documentation packaged for local access by AI agents and dev tools. |

### `@spree/sdk` — Store API client

The customer-facing SDK. Powers storefronts (Next.js or otherwise) and any client that needs read access to the catalog plus write access to carts, customers, addresses, and checkout. Auth modes: publishable key (guest) or JWT (logged-in customer).

Includes auto-generated TypeScript types and Zod schemas derived from the Rails Alba serializers — see the [type generation pipeline](../CLAUDE.md#type-generation-pipeline) in the root docs.

### `@spree/admin-sdk` — Admin API client

The back-office counterpart to `@spree/sdk`. Same patterns, but targets the Admin API and supports both **secret API key** (server-to-server, scope-based authorization) and **JWT** (admin user, CanCanCan-based authorization) auth modes. Used by the `@spree/dashboard` app and by integrations and admin tooling.

### `@spree/seller-sdk` — Seller API client

The client for the Seller API, which marketplace sellers use to manage their own products, orders and fulfillment. Used by `@spree/seller-dashboard`.

### `@spree/dashboard`, `@spree/dashboard-core`, `@spree/dashboard-ui` — the admin dashboard stack

The Spree 6.0 admin is a three-package stack:

- **`@spree/dashboard-ui`** — the design system. Shadcn primitives + headless composed components (PageHeader, ResourceTable, AppSidebar, …) + design tokens. **Headless rule:** components accept their data via props, never import providers or hooks. Source-only; the consuming Vite/Tailwind app compiles it. Pluggable into any React app, not just `@spree/dashboard`.
- **`@spree/dashboard-core`** — the framework. The four registries (table, nav, slot, settings-nav), the four providers (auth, permission, store, theme), generic infra hooks (`use-auth`, `use-permissions`, `use-resource-mutation`, `use-direct-upload`, `use-global-search`, …), the admin SDK client singleton, and the `defineDashboardPlugin` extension facade. **This is what plugin authors import** to register navigation, slots, table columns, and routes.
- **`@spree/dashboard`** — the deployable SPA. Routes, resource hooks (`use-orders`, `use-products`, `use-customers`, …), Zod schemas, locale strings, the app shell. Composes the other two. Built with Vite + TanStack Router (file-based) + TanStack Query + React Hook Form + Tailwind.

Plugin authors install `@spree/dashboard-ui` + `@spree/dashboard-core` as peer dependencies. The seller panel (`@spree/seller-dashboard`), white-label admins, and other custom variants compose the same packages with their own routes and shell. Merchants run the dashboards from the `dashboard-starter` and `seller-dashboard-starter` templates.

Architecture, extension points (table registry, navigation registry, component injection), the package boundary rules, and the phased migration are documented in [`docs/plans/6.0-admin-spa.md`](../docs/plans/6.0-admin-spa.md). Local setup for the SPA is in [`packages/dashboard/README.md`](./dashboard/README.md).

The three packages always release together under one version, and ship with Spree 6.0.

### `@spree/core` — Universal code

The code every Spree client shares, whatever it runs on: code lists generated from the API references, money helpers that work on decimal strings without floating point, and the filter types. No dependencies and no network calls. The SDKs bundle it and re-export its code lists and money helpers, so SDK users never install it separately. It is the home for any code a client could use — a conversion, a format, a rule shared with the server — and the base for moving more of Spree to TypeScript.

### `@spree/sdk-core` — Shared internals

Private package. Provides `createRequestFn()`, `SpreeError`, retry logic, and Ransack query-param transformation (`transformListParams()`), and re-exports `@spree/core`. Consumed by the SDKs; not intended for direct use.

### `@spree/cli` — Project management CLI

Commands for projects scaffolded via `create-spree-app`: starting/stopping services, running migrations, opening Rails consoles, loading sample data, etc. Bundled automatically into new projects.

### `create-spree-app` — Project scaffolder

The recommended entry point for new Spree projects. Clones [`spree/spree-starter`](https://github.com/spree/spree-starter), optionally adds the Next.js storefront, and runs first-time setup.

### `@spree/docs` — Documentation bundle

Spree developer documentation (core concepts, customization, API reference, integration guides) packaged as plain Markdown so AI agents and offline tooling can read it from `node_modules/@spree/docs/dist/`. Built from the `docs/` tree at the repo root.

## Working in the monorepo

From the repo root:

```bash
pnpm install      # install workspace deps
pnpm build        # turbo-cached build for all packages
pnpm test         # run all package tests
pnpm typecheck    # TypeScript across all packages
pnpm lint         # Biome lint
pnpm lint:fix     # Biome lint + auto-fix
pnpm format       # Biome format-write
```

Per-package commands are documented in each package's `README.md`. Changesets for versioning go in the root [`.changeset/`](../.changeset/) directory (`pnpm changeset`), never in a package's own directory.
