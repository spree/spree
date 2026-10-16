# Agent Instructions

`CLAUDE.md` only imports this file — edit this one.

This is the Spree seller panel for this marketplace — a Vite + React app. The
shell ships in `@spree/seller-dashboard`; this project holds your
customizations. Sellers manage their own catalog and orders here.

Full docs: https://spreecommerce.org/docs/developer/dashboard/overview

## Running it

Start the Spree API with `spree dev` from the project root (`../..`) — it is
only ever run through the Spree CLI; see the project root's `AGENTS.md`. Then
run this app's own dev server here with `pnpm dev` (or `npm run dev`); the
Spree CLI does not start the seller panel for you.

## Imports

Import from `@spree/seller-dashboard` — it re-exports the framework and the design
system, so there is no need to work out which package an export lives in.

```ts
import { defineDashboardPlugin, sellerClient, Button, ResourceTable } from '@spree/seller-dashboard'
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
| `src/pages/` | Larger components rendered inside slots | `payout-summary.tsx` |
| `src/hooks/` | Seller API wrappers | `use-payouts.ts` |
| `src/tables/` | `defineTable` calls | `brands.tsx` |
| `src/schemas/` | Zod schema + `FormValues` | `brand.ts` |
| `src/slots/` | Widgets injected into built-in pages | `seller-payout-card.tsx` |
| `src/locales/` | Your `admin.*` translation keys | `en.json` |

Keep `plugins.ts` a map of what exists, not an implementation.

The seller panel does not support adding new pages yet: plugins can remove
built-in navigation entries, add widgets to the slots built-in screens expose,
and add table columns. A navigation entry pointing at a path the panel does
not have leads to a "not found" screen.

## Rules

- **The Seller API is the only data source.** Never reach into the Rails app or
  import server-rendered HTML. Seller endpoints are scoped to the signed-in
  seller by the server, never by the client. A missing endpoint is added to the API first.
- **Use the Seller API, through a hook.** Hooks call `sellerClient()`;
  components never call it directly. Never use `adminClient` here — it targets
  the Admin API, which sellers cannot sign in to.
- **There is no store context.** The panel's tenant is the signed-in seller, so
  `useStore()` throws here. Build query keys with `useResourceKey`, which scopes
  them to the seller.
- **Writes go through `useResourceMutation`.** It shows a toast for network
  and server failures but not for 422 validation errors — catch those in the
  form's submit handler with `mapSpreeErrorsToForm`, which puts each message on
  its field.
- **Every visible string goes through i18next** — page titles, column labels,
  buttons, empty states, toasts. Never hardcode English in JSX or in a table
  definition. Add each new key to every locale file the project ships.
- **Schemas hold canonical values, never labels.** Build `{ value, label }`
  pairs at render time so labels stay translatable.
- **Never embed an SDK entity type in a form-values type.** React Hook Form
  walks every nested key and the SDK's object graph overflows the TypeScript
  compiler.
- **A sortable or filterable column must be allowlisted for Ransack** on the
  model, or the request fails at runtime. That change belongs to the Spree API
  in `../../server/` — follow `../../server/AGENTS.md`.
- **Destructive actions that fire straight from a click need a confirm** —
  `useConfirm()` with `variant: 'destructive'`.

## Checks

Run these with the project's package manager (`pnpm`, `npm run` or `yarn`):

```bash
pnpm typecheck
pnpm lint
pnpm test        # unit tests (Vitest, Node environment)
pnpm build
```

Test the logic between the UI and the API — query keys, payload mapping, permission predicates. Do not write tests that render a component to assert its markup; that tests React. Use `pnpm test:e2e` when a browser is genuinely needed.
