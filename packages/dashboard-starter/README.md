# Spree Dashboard Starter

The host app for the [Spree React Dashboard](https://spreecommerce.org/docs/developer/dashboard/overview) — the admin for your Spree store. `@spree/dashboard` is the actual app shell (routes, chrome, resource pages); this project is your customization point: plugins, your own pages, theming, and deployment config.

> **Monorepo note.** The canonical source of this template lives at `packages/dashboard-starter` in [spree/spree](https://github.com/spree/spree), where its Spree dependencies resolve via the pnpm workspace and `@spree/dashboard-plugin-example` is installed as a devDependency — booting it here doubles as the end-to-end test for the plugin pipeline. At build time, `@spree/cli` and `create-spree-app` embed a standalone rendering of it (workspace deps rewritten to the published versions — see `scripts/sync-starter.mjs`), which is what `spree add dashboard` and the create-spree-app dashboard prompt scaffold from.

## Develop

```bash
pnpm install
cp .env.example .env.local   # optional — VITE_API_PROXY_TARGET if your API isn't on :3000
pnpm dev                     # http://localhost:5173
```

The dev server proxies `/api` to your server API so the SPA stays same-origin — don't set `VITE_SPREE_API_URL` in dev (it switches the SDK to absolute cross-origin URLs, which breaks on CORS and the auth cookie).

Sign in with an admin account — authentication is interactive (JWT + refresh cookie). No API keys belong in `.env.local`: every `VITE_`-prefixed value is compiled into the client bundle.

## Install a dashboard plugin

```bash
pnpm add @acme/reviews-plugin
# restart the dev server
```

That's the whole install. `spreeDashboardPlugin()` (see `vite.config.ts`) discovers any dependency carrying the `spree.dashboard.plugin` marker, activates it through the `virtual:spree-dashboard-plugins` module imported in `src/main.tsx`, and wires its Tailwind classes.

## Customize

`src/plugins.ts` is yours — register nav entries, routes, slot widgets, and table columns with `defineDashboardPlugin` from `@spree/dashboard-core`. Same API the distributed plugins use; see the [customization quickstart](https://spreecommerce.org/docs/developer/dashboard/customization/quickstart).

**Import everything from `@spree/dashboard`.** It re-exports the framework
(registries, providers, hooks, the Admin API client) and the design system, so
you never have to remember which package a given export lives in:

```ts
import { defineDashboardPlugin, useStore, Button, ResourceTable } from '@spree/dashboard'
```

`@spree/dashboard-core` and `@spree/dashboard-ui` remain installed and
importable when you want them directly — a handful of components exist in
both, where the design system's version takes its data as props and the
framework's fetches its own. The facade gives you the framework's.

Brands will not be your only customization, so this starter ships the same layout `@spree/dashboard` uses internally: organized by kind, one file per resource.

```
src/
├── plugins.ts     registrations only — the map of what you added
├── pages/         one file per screen        brands.tsx, brand-detail.tsx
├── hooks/         one file per resource      use-brands.ts
├── tables/        one file per resource      brands.tsx
├── schemas/       one file per resource      brand.ts
├── slots/         widgets injected into      product-brand-card.tsx
│                  built-in pages
└── locales/       your translations          en.json
```

Adding a resource touches one file in each directory, which is why the split
is by kind rather than by feature — you always know where a thing lives.

**`pages/`** — a screen composes `ResourceLayout` with a `PageHeader` and
renders a `ResourceTable` or a form. It does not fetch data itself. Register
it as a route in `plugins.ts`:

```tsx
import { BrandsPage } from './pages/brands'

defineDashboardPlugin({
  routes: [{ key: 'brands', path: '/brands', component: BrandsPage }],
})
```

**`hooks/`** — named `use-<resource>.ts`, each wrapping the Admin API so
components never call `adminClient` directly. Build query keys with
`useResourceKey`, which scopes them to the current store; a bare `['brands']`
key leaks one store's data into another after a store switch. Use
`useResourceMutation` for writes — it maps 422 responses onto form fields
instead of firing a toast.

```ts
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useBrands() {
  return useQuery({
    queryKey: useResourceKey('brands'),
    queryFn: () => adminClient.request('GET', '/brands'),
  })
}
```

**`tables/`** — one `defineTable` call per resource, at module load, imported
from `plugins.ts` so it registers before the router mounts. Column changes to
built-in tables (products, orders, customers) live here too. A column marked
`sortable` or `filterable` must be allowlisted for Ransack on the model, or
the request fails.

**`schemas/`** — the Zod schema, its inferred `FormValues` type and defaults.
Hold canonical values only, never label strings: build `{ value, label }`
pairs at render time so labels stay translatable. Never embed an SDK entity
type (`Product`, `Order`) in a form-values type — React Hook Form walks every
nested key and the SDK's object graph overflows the TypeScript compiler.
Inline a short single-file schema instead.

**`slots/`** — components you inject into pages the dashboard already
renders, one file per widget. A slot widget takes its data from the slot's
context and, on a page with a host form, binds its inputs to that form with
`useHostForm()` rather than saving anything itself.

**`locales/`** — every visible string goes through i18next, including column
labels and button text. Keys live under a top-level `admin` object. Load the
bundle once at the top of `plugins.ts`:

```ts
import { i18n } from '@spree/dashboard-core'
import en from './locales/en.json'

i18n.addResourceBundle('en', 'translation', en, true, true)
```

## Test

Vitest and Playwright are configured — no setup needed.

```bash
pnpm test        # unit tests: src/**/*.test.ts
pnpm test:e2e    # end-to-end, through a browser
```

Unit tests run in Node rather than a DOM, because what is worth testing here is the logic between your UI and the API: query keys, payload mapping, permission predicates. Rendering a component to assert its markup tests React, not your feature — use an end-to-end test when you need a browser.

`pnpm test:e2e` starts the dashboard itself and reuses one you already have running, but expects your API to be up (`spree dev`). Point it elsewhere with `E2E_BASE_URL`.

## Build & deploy

The app root `Dockerfile` already builds this package and bakes it into the production image, available at `https://yourstore.com/dashboard` URL.

If you want to host it elsewhere, eg. on CDN you can build it manually.

```bash
pnpm build    # static assets in dist/
```

Deploy `dist/` to any static host. Set `VITE_SPREE_API_URL` to your production API at build time, and configure the API's CORS/cookie settings for the dashboard origin.
