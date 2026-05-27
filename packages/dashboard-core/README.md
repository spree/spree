# @spree/dashboard-core

Spree Dashboard framework. The extension API surface for plugin authors.

> **Phase 0 placeholder.** The package is scaffolded with its target structure; the registries, providers, and hooks haven't been extracted yet. See `docs/plans/6.0-admin-spa.md` → "Package Split".

## What goes here

- **Registries** (`src/lib/*-registry.ts`): `table`, `nav`, `slot`, `settings-nav`. Module-singleton stores driven by `useSyncExternalStore`. The plugin extension surface.
- **Providers** (`src/providers/`): `AuthProvider`, `PermissionProvider`, `StoreProvider`, `ThemeProvider`. Must be mounted by the consuming app shell.
- **Generic infra hooks** (`src/hooks/`): `use-auth`, `use-permissions`, `use-store`, `use-theme`, `use-resource-mutation`, `use-direct-upload`, `use-global-search`, `use-command-palette`, `use-copy-to-clipboard`, `use-scrolled`, `use-mobile`. Plus the cross-cutting infrastructure-flavored hooks (`use-countries`, `use-export`, `use-custom-fields`).
- **Admin SDK client** (`src/client.ts`): the Vite-aware `adminClient` singleton.
- **`defineDashboardPlugin`** (`src/plugin.ts`): the facade plugin authors call.

## Peer dependencies

`react`, `react-dom`, and `@spree/dashboard-ui` are peer deps. **Critical**: the four registries are module singletons. If a plugin bundles its own copy of `@spree/dashboard-core`, `registerSlot` writes to a different Map than `<Slot>` reads — silent no-op. Always keep `@spree/dashboard-core` as a peer dep in every plugin package; pnpm dedupes to a single instance.

## What's NOT here

Resource-specific hooks (`use-orders`, `use-products`, `use-customers`, `use-promotions`, …), Zod schemas, feature pages, route definitions, and locale strings live in `@spree/dashboard` (the app). We do not publish feature internals — that's the same call Medusa, Vendure, and Saleor make.

## Plugin authoring (post-Phase 2)

```tsx
import { defineDashboardPlugin } from '@spree/dashboard-core/plugin'
import { PageHeader, Button } from '@spree/dashboard-ui'

defineDashboardPlugin({
  nav: [{ key: 'reports', label: 'Reports', url: '/reports', position: 50 }],
  slots: {
    'product.form_sidebar': [{ id: 'my-widget', component: MyWidget }],
  },
})
```
