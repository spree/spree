/**
 * @spree/dashboard-plugin-example — Brands plugin.
 *
 * Reference implementation of a Spree dashboard plugin. Adds a "Brands"
 * feature to the admin:
 *
 *   - **Nav entry** in the main sidebar at `/$storeId/brands`.
 *   - **Custom route** at `/$storeId/brands` rendering a Brands list page
 *     built on `<ResourceTable>`.
 *   - **Table definition** for `'brands'`, declared via `defineTable` so
 *     ResourceTable can read column metadata, filters, default sort, etc.
 *   - **Slot widget** on the product detail page (`product.form_sidebar`)
 *     showing the brand assigned to the product.
 *   - **Column extension** on the core Products table — adds a "Brand"
 *     column that joins the product's `brand_id` against the brands client.
 *   - **Translations** under `admin.brands_plugin.*`, deep-merged into the
 *     dashboard's i18next namespace.
 *
 * A real plugin would also ship a Rails-side Brands engine (model, controller,
 * Alba serializer); this package only contains the dashboard half. See
 * `README.md` for the full setup story.
 *
 * Activation is automatic: this package declares the
 * `spree.dashboard.plugin` marker in its package.json, so a host running
 * `spreeDashboardPlugin()` discovers it and imports it via the
 * `virtual:spree-dashboard-plugins` module in the app entry — which
 * triggers the `defineDashboardPlugin` call below before first render.
 */
import { defineDashboardPlugin, defineTable, i18n } from '@spree/dashboard-core'
import { RelativeTime } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { PackageIcon } from 'lucide-react'
import { brandsClient } from './client'
import en from './locales/en.json'
import { ProductBrandCard } from './slots/product-brand-card'
import type { Brand } from './types'

// ---------------------------------------------------------------------------
// 1. Register translations
// ---------------------------------------------------------------------------
// `deep: true` + `overwrite: true` merge our `admin.brands_plugin.*` keys
// into the framework's existing `admin.*` namespace without dropping anything.
// See @spree/dashboard-core's README → "Translations".
i18n.addResourceBundle('en', 'translation', en, true, true)

// ---------------------------------------------------------------------------
// 2. Declare the Brands table
// ---------------------------------------------------------------------------
// Must run before `<ResourceTable tableKey="brands" />` mounts. defineTable
// is idempotent on the same key, but its initial declaration is the source
// of truth for which columns/filters/sort exist. Plugins can add columns
// after the fact via `tables.brands.addColumn`.
defineTable<Brand>('brands', {
  title: i18n.t('admin.brands_plugin.table.title'),
  searchParam: 'search',
  searchPlaceholder: i18n.t('admin.brands_plugin.table.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyMessage: i18n.t('admin.brands_plugin.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.brands_plugin.fields.name'),
      sortable: true,
      filterable: true,
      default: true,
      // Typed against the host's generated route tree — the plugin's file
      // routes (src/routes/) are compiled into it, so no casts needed.
      render: (b) => (
        <Link
          to="/$storeId/brands/$brandId"
          params={{ brandId: b.id }}
          className="font-medium text-foreground no-underline"
        >
          {b.name}
        </Link>
      ),
    },
    {
      key: 'slug',
      label: i18n.t('admin.brands_plugin.fields.slug'),
      sortable: true,
      filterable: true,
      default: true,
      render: (b) => b.slug,
    },
    {
      key: 'products_count',
      label: i18n.t('admin.brands_plugin.fields.products_count'),
      default: true,
      className: 'text-right tabular-nums',
      render: (b) => b.products_count,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.brands_plugin.fields.created_at'),
      sortable: true,
      default: false,
      render: (b) => <RelativeTime iso={b.created_at} />,
    },
  ],
})

// ---------------------------------------------------------------------------
// 3. Wire everything into defineDashboardPlugin
// ---------------------------------------------------------------------------
defineDashboardPlugin({
  nav: [
    {
      key: 'brands',
      label: i18n.t('admin.brands_plugin.nav'),
      path: '/brands',
      icon: PackageIcon,
      // Position 35 puts "Brands" between Products (30) and Customers (40)
      // in core's default sidebar ordering.
      position: 35,
      // Hide the entry for admins who can't read brands. Permission-aware
      // navigation matches core's behavior.
      subject: 'Spree::Brand',
    },
  ],
  // Routes are NOT registered here: this plugin ships file routes in
  // src/routes/ (declared via the package.json marker), which the host build
  // compiles into its typed route tree. The `routes:` registry option remains
  // for dynamic, host-app cases — see the routes customization guide.
  slots: {
    'product.form_sidebar': [
      {
        id: 'brand-card',
        // Cast because `defineDashboardPlugin`'s `slots` is typed as a
        // generic-erased `Record<string, SlotEntry[]>` — the host page knows
        // its slot context shape, but the plugin facade doesn't. The slot
        // catalogue in the dashboard's source documents which context each
        // named slot provides (`product.form_sidebar` → `{ product }`).
        component: ProductBrandCard as never,
        // Render below core's first-party cards (which use 100, 200, …).
        position: 250,
      },
    ],
  },
  tables: {
    // Add a "Brand" column to the existing core Products table. Plugin
    // authors extending built-in resources rarely need more than a column
    // or two; for richer integrations, register a slot on the product form.
    products: {
      add: [
        {
          key: 'brand',
          label: i18n.t('admin.brands_plugin.products_column.label'),
          default: false,
          render: (product: { brand_id?: string | null }) =>
            product.brand_id ? <BrandNameCell brandId={product.brand_id} /> : '—',
        },
      ],
    },
  },
})

// ---------------------------------------------------------------------------
// Internal: render a brand name by ID for the products-table column. Looks
// up via brandsClient; the dashboard's TanStack Query cache de-dupes
// requests across rows.
// ---------------------------------------------------------------------------
function BrandNameCell({ brandId }: { brandId: string }) {
  const { data } = useQuery({
    queryKey: ['plugin-brands', 'brand', brandId],
    queryFn: () => brandsClient.get(brandId),
    staleTime: 5 * 60_000,
  })
  return <span>{data?.name ?? '…'}</span>
}

// Re-export the public API of this plugin in case the host app wants to
// reach into it (e.g. to invalidate brand queries from outside).
export { brandsClient } from './client'
export type { Brand, BrandCreateParams, BrandUpdateParams } from './types'
