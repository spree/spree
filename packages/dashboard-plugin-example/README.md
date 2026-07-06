# @spree/dashboard-plugin-example

Reference implementation of a Spree dashboard plugin. Adds a "Brands" feature to the admin via `defineDashboardPlugin` from `@spree/dashboard-core`.

This package is the runnable companion to the [Dashboard section](../../docs/developer/dashboard/) of the developer docs. Start with [`overview.mdx`](../../docs/developer/dashboard/overview.mdx) for the lay of the land, then [`plugins/overview.mdx`](../../docs/developer/dashboard/plugins/overview.mdx) for the packaging story. Read the source here for a concrete template you can copy.

## What it demonstrates

Six extension points, all in one plugin:

1. **Nav entry** — adds "Brands" to the main sidebar between Products and Customers
2. **Custom routes** — `/$storeId/brands` (list page using `<ResourceTable>`) and `/$storeId/brands/$brandId` (detail page reading the `$brandId` path param)
3. **Table definition** — `defineTable('brands', ...)` declares columns, default sort, search params
4. **Slot widget** — the product detail page's right sidebar shows a "Brand" card via the `product.form_sidebar` slot
5. **Table column extension** — adds a "Brand" column to the existing core Products table
6. **Translations** — `admin.brands_plugin.*` keys deep-merged into the framework's i18next namespace

## Backend assumption

The plugin calls `adminClient.request('GET', '/brands')` etc. against a hypothetical Brands Admin API. **This package does not ship that backend** — a real Brands plugin would publish a Rails engine (`spree_brands`) alongside this dashboard plugin that registers:

- `Spree::Brand` model
- `Spree::Api::V3::Admin::BrandsController` (a `ResourceController` subclass)
- `Spree::Api::V3::Admin::BrandSerializer` (Alba)
- Routes under `/api/v3/admin/brands`
- CanCanCan ability for `Spree::Brand`

The dashboard plugin is the front end; the gem is the back end. They ship together but live in separate packages.

For the request layer pattern (`adminClient.request<T>` against custom endpoints), see [Custom Admin Endpoints](../../docs/developer/sdk/admin/extending.mdx) in the Spree docs.

## Activate this plugin in the dashboard

Add a side-effect import to your dashboard app's entry (`packages/dashboard/src/main.tsx` for the bundled dashboard, your own `main.tsx` for a custom admin app):

```ts
import '@spree/dashboard-plugin-example'
```

The import must run **before the router mounts** so the route registry is populated when the catch-all dispatcher reads it. The single side-effect import triggers everything: nav entry registers, `/brands` route mounts, slot widget appears on product pages, table column lands on the products table.

## File layout

```
src/
├── index.tsx                          ← plugin entry — defineDashboardPlugin call
├── types.ts                           ← Brand interface (would be Typelizer-generated in a real plugin)
├── client.ts                          ← adminClient.request wrappers
├── routes/
│   └── brands-list.tsx                ← /brands page using <ResourceTable>
├── slots/
│   └── product-brand-card.tsx        ← product.form_sidebar widget
└── locales/
    └── en.json                        ← plugin translations
```

## Per-extension-point notes

### `defineTable` runs at import time

The table definition (`defineTable('brands', ...)`) is declared at module scope so it's registered as soon as the plugin's entry is imported — before `<ResourceTable tableKey="brands">` ever mounts. The catch-all route dispatcher reads from the route registry on every navigation, so plugin registration before first render isn't strictly required, but mountain-then-register patterns make for fragile UX. Always register at module top-level.

### Nav `subject` gates visibility

`subject: 'Spree::Brand'` on the nav entry hides the sidebar item for admins without `read` permission on brands. The catch-all route checks the same subject and renders a 403 fallback if a user reaches `/brands` via a direct URL despite not having permission. Server-side enforcement still runs — this is UX, not authorization.

### Slot context shape is typed by the slot, not the plugin

`product.form_sidebar` slots receive `{ product, permissions, store, user }`. The plugin's `<ProductBrandCard>` types only the fields it reads (`{ product: { id, brand_id } }`); a slot author should never assume more than what's documented in the dashboard's slot catalogue. Slot names and their context shapes are documented per-page in `@spree/dashboard`.

### Translation collisions

`addResourceBundle` deep-merges, so two plugins both writing `admin.actions.share` would race — last write wins. Put plugin-specific text under your own namespace (`admin.brands_plugin.*`) to stay clear of the framework and other plugins. See the dashboard-core README for the full convention.

## Development workflow

This package lives in the Spree monorepo but mirrors the shape of a real external plugin. Build it with the rest of the workspace:

```bash
pnpm install
pnpm -F @spree/dashboard-plugin-example typecheck
```

The dashboard imports it via the workspace symlink (`@spree/dashboard-plugin-example` in `packages/dashboard/package.json` once added). Run the dashboard with `pnpm dev` and the plugin's nav entry, slot widget, table column, and `/brands` route all light up.

## License

MIT. Copy this package shape for your own plugin; it's intended as a template.
