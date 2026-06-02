# @spree/dashboard-core

Spree Dashboard framework. Registries, providers, infra hooks, the admin SDK client, and the `defineDashboardPlugin` extension API.

This is the package plugin authors install. Use it to register nav entries, slot widgets, table column extensions, and settings pages from a separate npm package that gets imported into `@spree/dashboard` at boot.

## Install

```bash
pnpm add @spree/dashboard-core @spree/dashboard-ui
```

Peer dependencies that the consuming app provides: `react`, `react-dom`, `@spree/admin-sdk`, `@spree/dashboard-ui`, `@tanstack/react-query`, `@tanstack/react-router`, `@tanstack/react-hotkeys`, `react-hook-form`, `react-i18next`, `i18next`, `sonner`.

**Why peer deps:** the four registries (nav, slot, table, settings-nav) are module singletons. If your plugin bundles its own copy of `@spree/dashboard-core`, `registerSlot` writes to a different Map than the app's `<Slot>` reads — silent no-op. Same applies to React, the query client, the router instance, and the i18n singleton. pnpm dedupes these to a single instance as long as they're peers.

## What's in the box

```
@spree/dashboard-core
├── adminClient                    # @spree/admin-sdk instance, baseUrl wired to VITE_SPREE_API_URL
│
├── Providers (mount in your app shell, in this order)
│   ├── AuthProvider               # JWT + refresh token, /auth/refresh on cold load
│   ├── PermissionProvider         # /api/v3/admin/me → CanCanCan rules
│   └── StoreProvider              # current store context (multi-store)
│
├── Registries (the four extension points)
│   ├── nav                        # sidebar items
│   ├── settingsNav                # settings sub-shell groups + items
│   ├── slot                       # named injection points (`product.form_sidebar`, ...)
│   └── tables                     # column add/remove/update per list view
│
├── Infra hooks
│   ├── useAuth                    # { token, user, login(), logout() }
│   ├── usePermissions             # CanCanCan rules + <Can> helper
│   ├── useStore                   # current store
│   ├── useResourceMutation        # useMutation + toast + form-error mapping
│   ├── useDirectUpload            # Active Storage direct-upload
│   ├── useGlobalSearch            # cross-resource search
│   ├── useCommandPalette          # ⌘K palette state
│   ├── useCopyToClipboard
│   ├── useScrolled
│   ├── useCountries               # admin/countries (geo data, cached)
│   ├── useExport                  # CSV export jobs (polled)
│   └── useCustomFields            # metafield definitions + values
│
├── i18n (i18next + react-i18next)
│   ├── Base translation namespace (`admin.actions.*`, `admin.common.*`, `admin.validation.*`, …)
│   ├── Trans, useTranslation      # re-exported from react-i18next
│   └── i18n                       # the i18next singleton (call addResourceBundle to extend)
│
├── Helpers
│   ├── filtersToRansack           # UI filter shape → Ransack params
│   ├── mapSpreeErrorsToForm       # 422 → RHF setError
│   ├── formatPrice / getInitials
│   ├── Subject, Action            # CanCanCan subject/action constants
│   └── queryClient                # TanStack Query client singleton
│
└── defineDashboardPlugin          # the one-call extension facade
```

Additional entry point:

- `@spree/dashboard-core/vite` — Vite plugin that wires Tailwind v4. See [Vite integration](#vite-integration).

## Vite integration

The dashboard relies on Tailwind v4, which doesn't scan `node_modules` by default and only accepts filesystem paths in `@source` directives (not bare package specifiers). The `spreeDashboardPlugin` from `@spree/dashboard-core/vite` resolves each Spree dashboard package and each host-named plugin through Node module resolution and injects matching `@source` directives into your CSS entry at build time. It also bundles `@tailwindcss/vite` itself so plugin ordering is guaranteed — hosts must NOT register `@tailwindcss/vite` separately.

### Using the full `@spree/dashboard` app shell

```ts
// host vite.config.ts
import { spreeDashboardPlugin } from '@spree/dashboard-core/vite'
import { TanStackRouterVite } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [
    spreeDashboardPlugin({
      plugins: [
        '@my-store/orders-dashboard-plugin',
        '@my-store/wishlists-dashboard-plugin',
      ],
    }),
    TanStackRouterVite(),
    react(),
  ],
})
```

```css
/* host src/styles.css */
@import "@spree/dashboard/styles.css";
```

### Building a custom dashboard on `@spree/dashboard-core` + `@spree/dashboard-ui`

If you're not using `@spree/dashboard`'s app shell — e.g. a vendor portal or B2B buyer admin built directly on the registries and primitives — point `cssEntry` at your own CSS file:

```ts
// custom-dashboard vite.config.ts
import { spreeDashboardPlugin } from '@spree/dashboard-core/vite'

export default defineConfig({
  plugins: [
    spreeDashboardPlugin({
      cssEntry: './src/admin.css',
      plugins: ['@my-store/vendor-portal-plugin'],
    }),
    // host owns react, router, etc.
  ],
})
```

```css
/* custom-dashboard src/admin.css */
@import "@spree/dashboard-ui/styles.css";
/* Tailwind auto-scans the host's own src/, so host-authored classes
   work without configuration. The Vite plugin injects @source for
   @spree/dashboard-core, @spree/dashboard-ui, and any named plugins. */
```

### `@spree/dashboard-ui` only (no `@spree/dashboard-core`)

If you only need design-system primitives and tokens, no registries, no providers — you don't need this Vite plugin at all. Install `@spree/dashboard-ui`, set up `@tailwindcss/vite` yourself, and import its stylesheet:

```css
@import "@spree/dashboard-ui/styles.css";
```

`dashboard-ui/styles.css` carries its own `@source` directives covering its components.

### Options

```ts
spreeDashboardPlugin({
  /**
   * Path to the host's CSS entry file, relative to the host's project root.
   * The plugin injects @source directives into this file. Defaults to
   * `./src/styles.css`.
   */
  cssEntry: './src/styles.css',

  /**
   * Names of installed dashboard plugin packages. Each must be a resolvable
   * npm specifier. The plugin resolves each via Node module resolution and
   * tells Tailwind to scan its source files.
   */
  plugins: ['@my-store/orders-plugin'],
})
```

### What plugin authors must do

Ship `src/` in their published package so Tailwind has source files to scan:

```json
// plugin's package.json
{
  "name": "@my-store/orders-dashboard-plugin",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "files": ["src", "README.md"]
}
```

Plugin authors do NOT need to ship pre-built CSS, configure Tailwind, or care about the host's package manager — adding the plugin name to the host's `plugins: [...]` is enough.

## Plugin authoring — the basics

Your plugin is an npm package. Its entry module calls `defineDashboardPlugin({...})` at import time. The dashboard app imports your entry module before first render — every registry handles late registration via `useSyncExternalStore`, so even if your plugin loads asynchronously the sidebar/slots re-render.

```tsx
// my-spree-plugin/src/index.ts
import { defineDashboardPlugin, usePermissions } from '@spree/dashboard-core'
import { Card, CardHeader, CardTitle, CardContent } from '@spree/dashboard-ui'
import { BarChartIcon } from 'lucide-react'

function WishlistsWidget({ product }: { product: { id: string; wishlist_count: number } }) {
  return (
    <Card>
      <CardHeader><CardTitle>Wishlists</CardTitle></CardHeader>
      <CardContent>{product.wishlist_count} customers</CardContent>
    </Card>
  )
}

defineDashboardPlugin({
  nav: [
    { key: 'wishlists', label: 'Wishlists', path: '/wishlists', icon: BarChartIcon, position: 50 },
  ],
  slots: {
    'product.form_sidebar': [
      { id: 'wishlist-count', component: WishlistsWidget, position: 50 },
    ],
  },
  tables: {
    products: {
      add: [{ key: 'wishlist_count', label: 'Wishlists', sortable: true }],
    },
  },
})
```

Then in the consuming app's entry point:

```ts
// my-spree-app/src/main.tsx
import '@spree/dashboard-core/lib/i18n'   // base translations
import 'my-spree-plugin'                  // your plugin registers extensions
// ...rest of normal dashboard bootstrap
```

## Translations — extending the base namespace

Plugin authors **inherit the framework's base translation namespace** (`admin.actions.save`, `admin.common.no_results`, `admin.validation.required`, `admin.fields.<simple>.label`, …) for free. To add your own keys, call `i18n.addResourceBundle` after the side-effect import.

```ts
// my-spree-plugin/src/index.ts
import { i18n } from '@spree/dashboard-core'
import en from './locales/en.json'
//
// {
//   "admin": {
//     "wishlists": {
//       "title": "Wishlists",
//       "empty_state": "No wishlists yet"
//     }
//   }
// }

i18n.addResourceBundle('en', 'translation', en, true, true)
// `deep: true` + `overwrite: true` merge nested keys into the base namespace
// without dropping anything the framework provided.
```

Now anywhere in your plugin you can mix base keys and your own:

```tsx
import { useTranslation } from '@spree/dashboard-core'

function WishlistsHeader() {
  const { t } = useTranslation()
  return (
    <header>
      <h1>{t('admin.wishlists.title')}</h1>
      <button>{t('admin.actions.create')}</button>{/* base */}
    </header>
  )
}
```

### When plugins should pick their own sub-namespace

`addResourceBundle` deep-merges into `admin.*`, so `admin.actions.save` from a plugin would **overwrite** the framework's `admin.actions.save`. To avoid collisions, put plugin-specific text under a vendor-prefixed key:

```jsonc
{
  "admin": {
    "wishlists": { ... }     // ok — fresh namespace under admin
  }
}
```

Not:

```jsonc
{
  "admin": {
    "actions": {
      "share": "Share"        // collides if the framework ever adds `admin.actions.share`
    }
  }
}
```

Prefer `admin.<plugin>.*` for everything you own. Use base keys (`admin.actions.*`, `admin.common.*`, `admin.fields.<simple>.*`) by *reading* them, not by extending them.

### Multi-locale plugins

Same pattern, once per locale:

```ts
import { i18n } from '@spree/dashboard-core'
import en from './locales/en.json'
import fr from './locales/fr.json'

i18n.addResourceBundle('en', 'translation', en, true, true)
i18n.addResourceBundle('fr', 'translation', fr, true, true)
```

The framework currently ships English only; once Spree's locale list grows the same `addResourceBundle` pattern applies.

## Extension surface — the four registries

### `nav` — main sidebar items

```ts
import { nav } from '@spree/dashboard-core'
import { PackageIcon } from 'lucide-react'

nav.add({
  key: 'wishlists',
  label: 'Wishlists',
  path: '/wishlists',          // prefixed with /$storeId at render time
  icon: PackageIcon,
  position: 50,                // built-ins use 100/200/300 — slot in between
  subject: 'Spree::Wishlist',  // CanCanCan subject — hides item without permission
})

// Or: insert relative to an existing entry
nav.insertAfter('orders', { key: 'wishlists', label: 'Wishlists', path: '/wishlists' })
nav.update('orders', { label: 'All Orders' })
nav.remove('legacy-thing')
```

### `settingsNav` — settings sub-shell

Settings entries cluster under groups:

```ts
import { settingsNav } from '@spree/dashboard-core'

settingsNav.addGroup({ key: 'integrations', label: 'Integrations', position: 500 })
settingsNav.add({
  key: 'wishlist-settings',
  label: 'Wishlists',
  path: '/wishlists',          // prefixed with /$storeId/settings at render time
  group: 'integrations',
  position: 100,
})
```

### `registerSlot` — named injection points

Slots are typed by their context. A `product.form_sidebar` slot receives the product, ambient permissions, store, and user:

```tsx
import { registerSlot } from '@spree/dashboard-core'
import { Card } from '@spree/dashboard-ui'

registerSlot<{ product: { id: string; wishlist_count: number } }>('product.form_sidebar', {
  id: 'wishlist-count',
  component: ({ product, permissions }) => {
    if (!permissions?.can('manage', 'Spree::Wishlist')) return null
    return <Card>Wishlists: {product.wishlist_count}</Card>
  },
  position: 50,
  // Optional visibility predicate — receives the merged context
  if: (ctx) => ctx.product.wishlist_count > 0,
})
```

Built-in slot names match the legacy Rails admin's `render_admin_partials` mental model (e.g. `product.form_sidebar`, `order.page_body`, `product.actions`). The full list is documented per route in `@spree/dashboard`.

### `tables` — list-view column extensions

```ts
import { tables } from '@spree/dashboard-core'

tables.products.addColumn({
  key: 'wishlist_count',
  label: 'Wishlists',
  sortable: true,
  render: (product) => product.wishlist_count,
})
tables.products.removeColumn('legacy_column')
tables.products.updateColumn('total', { label: 'Net total' })
```

**Ordering:** built-in tables register lazily via side-effect imports in route files (`import '@/tables/products'` inside the products route), so calling `tables.products.addColumn(...)` from your plugin's entry module — which loads before any route mounts — would otherwise race the registration. The mutator handles this transparently: mutations on a not-yet-registered table are queued and replayed when `defineTable('products', ...)` runs. Mutations on tables that never register stay pending and never fire, which is the right behavior when your plugin extends an optional feature.

## `defineDashboardPlugin` — one-call facade

All four registries in a single declarative config:

```ts
import { defineDashboardPlugin } from '@spree/dashboard-core/plugin'

defineDashboardPlugin({
  nav: [...],
  settingsNavGroups: [...],
  settingsNav: [...],
  slots: { 'product.form_sidebar': [...] },
  tables: {
    products: {
      add: [...],
      remove: ['legacy_column'],
      update: { total: { label: 'Net total' } },
    },
  },
})
```

Equivalent to calling the underlying registry methods directly. Use whichever feels right — the facade is purely ergonomic.

## What's NOT here

Resource-specific hooks (`use-orders`, `use-products`, `use-customers`, …), Zod schemas, feature pages, route definitions, and per-feature locale strings live in `@spree/dashboard` (the app). We do not publish feature internals. Plugin authors compose new pages out of `@spree/dashboard-ui` primitives + `@spree/dashboard-core` infra, not out of forked feature internals.

Theme and toast UI live in `@spree/dashboard-ui` (they're rendering concerns, no Spree backend coupling): `ThemeProvider`, `useTheme`, `Toaster`.

## Architectural notes

- **Client injection**: `adminClient` reads `import.meta.env.VITE_SPREE_API_URL` at build time. Three deployment topologies (dev proxy, prod single-origin, prod cross-origin) all share one code path. See `src/client.ts` for details.
- **i18n bootstrap**: `import '@spree/dashboard-core/lib/i18n'` initializes i18next with the base namespace. Must run before any component calls `useTranslation`. The dashboard's `i18n-setup.ts` does this + adds the app's resources via `addResourceBundle`. Plugins follow the same pattern.
- **Registries are module singletons**: see "Peer dependencies" above. Build your plugin with `@spree/dashboard-core` listed as a peer dep, not a regular dep.
