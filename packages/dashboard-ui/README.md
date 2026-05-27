# @spree/dashboard-ui

Spree Dashboard design system. Shadcn primitives + headless composed components + design tokens.

> **Phase 0 placeholder.** The package is scaffolded with its target structure, but the components haven't been extracted yet. See `docs/plans/6.0-admin-spa.md` → "Package Split" for the phased plan.

## What goes here

- `src/ui/` — shadcn primitives (Button, Input, Dialog, Sheet, Table, …). Copy-paste owned: fork into your own project as needed.
- `src/spree/` — composed components built on the primitives (PageHeader, ResourceTable, AppSidebar, …). **All headless: data and callbacks come in via props.** No provider imports, no hook calls, no SDK access.
- `src/styles.css` — design tokens + Tailwind theme. Import once from your Vite app.
- `src/lib/` — generic helpers (`cn`, formatters, …).

The headless rule is what makes the components composable from outside `@spree/dashboard` — a plugin author, an app developer building a vendor panel, or a third-party using just `@spree/dashboard-ui` can all instantiate the same components with their own data sources.

## Source-only package

This package ships **TypeScript source**, not a compiled bundle. Consumers compile it through their own Vite + Tailwind setup. This is required because Tailwind v4 scans source files in the consuming app for utility classes; a pre-compiled CSS bundle would miss classes only used by source-imported components.

## Peer dependencies

`react` and `react-dom` are peer deps. The consumer provides them.

## What's NOT here

Anything that needs a provider (auth, store, theme), a TanStack Query hook, or the Admin SDK lives in `@spree/dashboard-core`. The split is: **dashboard-ui is the design system, dashboard-core is the framework**.
