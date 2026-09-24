# Agent Instructions

This is the Spree seller panel for this marketplace — a Vite + React app. The
shell ships in `@spree/seller-dashboard`; this project holds your
customizations. Sellers manage their own catalog and orders here.

Full docs: https://spreecommerce.org/docs/developer/dashboard/overview

The admin dashboard is the reference implementation: when a component is
useful to both, extract it rather than copying it.

## Imports

Import from `@spree/seller-dashboard` — it re-exports the framework and the design
system, so there is no need to work out which package an export lives in.

```ts
import { defineDashboardPlugin, useStore, Button, ResourceTable } from '@spree/seller-dashboard'
```

`@spree/dashboard-core` and `@spree/dashboard-ui` stay importable for the few
components that exist in both: the design system's takes data as props, the
framework's fetches its own. The facade gives you the framework's.

## Where code goes

Organized by kind, one file per resource — the same layout the panel
uses internally.

| Directory | Holds | Naming |
|---|---|---|
| `src/plugins.ts` | Registrations only: nav, slots, tables | one file |
| `src/pages/` | One screen each | `brands.tsx` |
| `src/hooks/` | Admin API wrappers | `use-brands.ts` |
| `src/tables/` | `defineTable` calls | `brands.tsx` |
| `src/schemas/` | Zod schema + `FormValues` | `brand.ts` |
| `src/slots/` | Widgets injected into built-in pages | `seller-payout-card.tsx` |
| `src/locales/` | Your `admin.*` translation keys | `en.json` |

Adding a resource touches one file in each directory. Keep `plugins.ts` a map
of what exists, not an implementation.

## Rules

- **The Admin API is the only data source.** Never reach into the Rails app or
  import server-rendered HTML. Seller endpoints are scoped to the signed-in
  seller by the server, never by the client. A missing endpoint is added to the API first.
- **Wrap API calls in a hook.** Components never call `adminClient` directly.
- **Query keys are store-scoped.** Build them with `useResourceKey`; a bare
  `['brands']` key leaks one store's data into another after a store switch.
- **Writes go through `useResourceMutation`**, which maps 422 responses onto
  form fields instead of firing a toast.
- **Every visible string goes through i18next** — page titles, column labels,
  buttons, empty states, toasts. Never hardcode English in JSX or in a table
  definition. Add each new key to every locale file the project ships.
- **Schemas hold canonical values, never labels.** Build `{ value, label }`
  pairs at render time so labels stay translatable.
- **Never embed an SDK entity type in a form-values type.** React Hook Form
  walks every nested key and the SDK's object graph overflows the TypeScript
  compiler.
- **A sortable or filterable column must be allowlisted for Ransack** on the
  model, or the request fails at runtime.
- **Destructive actions that fire straight from a click need a confirm** —
  `useConfirm()` with `variant: 'destructive'`.

## Checks

```bash
pnpm typecheck
pnpm lint
pnpm test        # unit tests (Vitest, Node environment)
pnpm build
```

Test the logic between the UI and the API — query keys, payload mapping, permission predicates. Do not write tests that render a component to assert its markup; that tests React. Use `pnpm test:e2e` when a browser is genuinely needed.
