# @spree/dashboard-core

Spree Dashboard framework — registries, providers, infra hooks, the admin SDK client singleton, and the `defineDashboardPlugin` extension API.

This is the package plugin authors install. Use it to register nav entries, slot widgets, table column extensions, form fields, and settings pages from a separate npm package that `@spree/dashboard` activates at boot.

## Install

```bash
pnpm add @spree/dashboard-core @spree/dashboard-ui
```

**List `@spree/dashboard-core` (and React, the TanStack packages, i18next, …) as peer dependencies in your plugin.** The registries are module singletons — a bundled second copy would write to Maps the app never reads, a silent no-op. The [plugin distribution guide](https://spreecommerce.org/docs/developer/dashboard/plugins/distributing) covers the full peer list.

## Quick start

```ts
import { defineDashboardPlugin } from '@spree/dashboard-core/plugin'
import { PackageIcon } from 'lucide-react'
import { WishlistCard } from './wishlist-card'

defineDashboardPlugin({
  nav: [{ key: 'wishlists', label: 'Wishlists', path: '/wishlists', icon: PackageIcon }],
  slots: {
    'product.form_sidebar': [{ id: 'wishlist-count', component: WishlistCard }],
  },
  tables: {
    products: {
      add: [{ key: 'wishlist_count', label: 'Wishlists', render: (p) => p.wishlist_count }],
      remove: ['legacy_column'],
    },
  },
  formFields: { product: [{ name: 'tech_specs', from: (p) => p?.tech_specs ?? '' }] },
})
```

A second entry point, `@spree/dashboard-core/vite`, provides the Vite plugin that wires Tailwind v4 and plugin auto-discovery for custom hosts.

## Documentation

The full guides live on the docs site — this README intentionally stays short:

- [Dashboard overview](https://spreecommerce.org/docs/developer/dashboard/overview) & [concepts](https://spreecommerce.org/docs/developer/dashboard/concepts)
- [Customization quickstart](https://spreecommerce.org/docs/developer/dashboard/customization/quickstart) — nav, routes, slots, tables, translations, permissions
- [Slots catalog](https://spreecommerce.org/docs/developer/dashboard/slots-catalog) — every named injection point
- [Plugin authoring](https://spreecommerce.org/docs/developer/dashboard/plugins/overview) — scaffolding, publishing, distributing
- [Public API](https://spreecommerce.org/docs/developer/dashboard/public-api) — everything this package exports, with stability guarantees

## License

MIT
