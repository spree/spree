# Spree TypeScript Packages

This directory contains the TypeScript side of the Spree monorepo: SDKs, the React admin SPA, the CLI, project scaffolding, and the docs bundle. Everything here is managed with **pnpm workspaces** + **Turbo**, built with **tsup** (or Vite for the admin SPA), tested with **Vitest**, and linted with **Biome**. Versioning for published packages is handled by **Changesets**.

For monorepo-wide conventions (type generation pipeline, code style, testing) see the root [`CLAUDE.md`](../CLAUDE.md). For backend conventions see [`spree/`](../spree/).

## Status legend

| Badge | Meaning |
| --- | --- |
| **Stable** | Published to npm, follows semver, safe for production. |
| **Developer Preview** | Published to npm but API may change between minor versions. Pin exact versions. |
| **In Development** | Active work for an upcoming Spree release. Not yet published or only published behind a `next` dist-tag. |
| **Internal** | Private to the workspace (`"private": true`), not published. |

## Packages

| Package | npm | Status | Description |
| --- | --- | --- | --- |
| [`sdk`](./sdk) | [`@spree/sdk`](https://www.npmjs.com/package/@spree/sdk) | **Stable** (2.0 release candidate for Spree 6.0) | TypeScript client for the customer-facing **Store API v3**. |
| [`admin-sdk`](./admin-sdk) | [`@spree/admin-sdk`](https://www.npmjs.com/package/@spree/admin-sdk) | **In Development** (1.0 release candidate) | TypeScript client for the **Admin API v3**. |
| [`seller-sdk`](./seller-sdk) | [`@spree/seller-sdk`](https://www.npmjs.com/package/@spree/seller-sdk) | **In Development** (1.0 release candidate) | TypeScript client for the marketplace **Seller API v3**. |
| [`dashboard`](./dashboard) | [`@spree/dashboard`](https://www.npmjs.com/package/@spree/dashboard) | **In Development** (1.0 release candidate) | React SPA admin dashboard for Spree 6.0. Replaces the legacy Rails `spree/admin` engine. |
| [`dashboard-ui`](./dashboard-ui) | [`@spree/dashboard-ui`](https://www.npmjs.com/package/@spree/dashboard-ui) | **In Development** (1.0 release candidate) | Design system for the dashboard — shadcn primitives, headless composed components, design tokens. Source-only. |
| [`dashboard-core`](./dashboard-core) | [`@spree/dashboard-core`](https://www.npmjs.com/package/@spree/dashboard-core) | **In Development** (1.0 release candidate) | Dashboard framework — registries (table, nav, slot, settings-nav), providers, generic infra hooks, `defineDashboardPlugin`. The extension API surface. |
| [`seller-dashboard`](./seller-dashboard) | [`@spree/seller-dashboard`](https://www.npmjs.com/package/@spree/seller-dashboard) | **In Development** (1.0 release candidate) | React SPA seller panel for marketplace deployments, built from the dashboard packages. |
| [`dashboard-starter`](./dashboard-starter) | — | **Internal** | Host app for the admin dashboard; source of the `spree/dashboard-starter` template. |
| [`seller-dashboard-starter`](./seller-dashboard-starter) | — | **Internal** | Host app for the seller panel; source of the `spree/seller-dashboard-starter` template. |
| [`dashboard-plugin-example`](./dashboard-plugin-example) | — | **Internal** | Example dashboard plugin, the reference for the plugin authoring docs. |
| [`sdk-core`](./sdk-core) | — | **Internal** | Shared HTTP/retry/error layer used by the SDKs. Not published. |
| [`telemetry`](./telemetry) | — | **Internal** | Usage reporting shared by `@spree/cli` and `create-spree-app`. Bundled into both, not published. |
| [`cli`](./cli) | [`@spree/cli`](https://www.npmjs.com/package/@spree/cli) | **Stable** (3.x) | Docker-based CLI for managing Spree projects scaffolded with `create-spree-app`. |
| [`create-spree-app`](./create-spree-app) | [`create-spree-app`](https://www.npmjs.com/package/create-spree-app) | **Stable** (2.x) | One-shot scaffolder: `npx create-spree-app my-store`. Sets up the backend (Docker), the dashboard, and an optional Next.js storefront. |
| [`docs`](./docs) | [`@spree/docs`](https://www.npmjs.com/package/@spree/docs) | **Developer Preview** (0.x) | Spree developer documentation packaged for local access by AI agents and dev tools. |

### `@spree/sdk` — Store API client

The customer-facing SDK. Powers storefronts (Next.js or otherwise) and any client that needs read access to the catalog plus write access to carts, customers, addresses, and checkout. Auth modes: publishable key (guest) or JWT (logged-in customer).

Includes auto-generated TypeScript types and Zod schemas derived from the Rails Alba serializers — see the [type generation pipeline](../CLAUDE.md#type-generation-pipeline) in the root docs.

### `@spree/admin-sdk` — Admin API client

The back-office counterpart to `@spree/sdk`. Same patterns, but targets the Admin API and supports both **secret API key** (server-to-server, scope-based authorization) and **JWT** (admin user, CanCanCan-based authorization) auth modes. Used internally by the `@spree/dashboard` SPA and externally by integrations and admin tooling.

The SDK is a 1.0 release candidate, shipping with Spree 6.0.

### `@spree/dashboard`, `@spree/dashboard-core`, `@spree/dashboard-ui` — the admin dashboard stack

The Spree 6.0 admin is a three-package stack:

- **`@spree/dashboard-ui`** — the design system. Shadcn primitives + headless composed components (PageHeader, ResourceTable, AppSidebar, …) + design tokens. **Headless rule:** components accept their data via props, never import providers or hooks. Source-only; the consuming Vite/Tailwind app compiles it. Pluggable into any React app, not just `@spree/dashboard`.
- **`@spree/dashboard-core`** — the framework. The four registries (table, nav, slot, settings-nav), the four providers (auth, permission, store, theme), generic infra hooks (`use-auth`, `use-permissions`, `use-resource-mutation`, `use-direct-upload`, `use-global-search`, …), the admin SDK client singleton, and the `defineDashboardPlugin` extension facade. **This is what plugin authors import** to register navigation, slots, table columns, and routes.
- **`@spree/dashboard`** — the deployable SPA. Routes, resource hooks (`use-orders`, `use-products`, `use-customers`, …), Zod schemas, locale strings, the app shell. Composes the other two. Built with Vite + TanStack Router (file-based) + TanStack Query + React Hook Form + Tailwind.

Plugin authors install `@spree/dashboard-ui` + `@spree/dashboard-core` as peer dependencies. Seller panels, white-label admins, and other custom variants compose the same packages with their own routes/shell.

Architecture, extension points (table registry, navigation registry, component injection), the package boundary rules, and the phased migration are documented in [`docs/plans/6.0-admin-spa.md`](../docs/plans/6.0-admin-spa.md). Local setup for the SPA is in [`packages/dashboard/README.md`](./dashboard/README.md).

The three packages are a fixed release group: they always share one version and ship together with Spree 6.0.

### `@spree/sdk-core` — Shared internals

Private package. Provides `createRequestFn()`, `SpreeError`, retry logic, and Ransack query-param transformation (`transformListParams()`). Consumed by the SDKs; not intended for direct use.

### `@spree/telemetry` — Command line usage reporting

Private package. Reports one anonymous event per lifecycle command run from a terminal (`create-spree-app`, `spree init`, `dev`, `add`, …), and holds the opt-out rules shared by both tools. Bundled into `@spree/cli` and `create-spree-app` at build time, so a change here needs a changeset for those two. What is sent and how to turn it off: [Update Checks and Usage Data](https://spreecommerce.org/docs/developer/deployment/usage-data).

### `@spree/cli` — Project management CLI

Docker-based commands for projects scaffolded via `create-spree-app`: starting/stopping services, running migrations, opening Rails consoles, loading sample data, etc. Bundled automatically into new projects.

### `create-spree-app` — Project scaffolder

The recommended entry point for new Spree projects. Clones [`spree/spree-starter`](https://github.com/spree/spree-starter), wires up Docker Compose, optionally adds the Next.js storefront, and runs first-time setup. Replaces the legacy in-repo `server/` directory.

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

Per-package commands are documented in each package's `README.md`. Changesets for versioning go in the root `.changeset/` directory (`pnpm changeset`).
