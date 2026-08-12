import type { Category, Collection, Customer, Order, Product, Promotion } from '@spree/admin-sdk'
import { adminClient, defineSearchEntry, Subject, searchRegistry } from '@spree/dashboard-core'
import { StatusBadge } from '@spree/dashboard-ui'
import {
  FolderTreeIcon,
  LayersIcon,
  ShoppingCartIcon,
  TagIcon,
  TicketPercentIcon,
  UsersIcon,
} from 'lucide-react'
import type { ReactNode } from 'react'

// Each entry teaches the command palette how to search one resource: how to
// fetch matches, render a result row, and where a row navigates. Resources are
// matched server-side via Ransack predicates — no dedicated backend `search`
// scope required; the predicate is declared right here in `fetch`. Plugins add
// searchable resources the same way (import `searchRegistry`, call `add`).

searchRegistry.add(
  defineSearchEntry<Product>({
    key: 'products',
    headingKey: 'admin.nav.products',
    subject: Subject.Product,
    position: 100,
    fetch: (search, limit) => adminClient.products.list({ search, limit }).then((r) => r.data),
    getKey: (p) => p.id,
    getRoute: (p, storeId) => ({ to: `/${storeId}/products/${p.id}` }),
    renderRow: (p) => (
      <>
        <IconOrThumbnail thumbnailUrl={p.primary_media?.mini_url ?? null} icon={<TagIcon />} />
        <span className="flex-1 truncate">{p.name}</span>
        <StatusBadge status={p.status} />
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Category>({
    key: 'categories',
    headingKey: 'admin.nav.categories',
    subject: Subject.Category,
    position: 150,
    // No backend `search` scope on Taxon — match the name via a Ransack `cont`
    // predicate (whitelisted on Spree::Taxon), sorted by the full hierarchy path
    // so nested categories read top-down. Mirrors the categories page search.
    fetch: (search, limit) =>
      adminClient.categories
        .list({ name_cont: search, limit, sort: 'pretty_name' })
        .then((r) => r.data),
    getKey: (c) => c.id,
    getRoute: (c, storeId) => ({ to: `/${storeId}/products/categories/${c.id}` }),
    renderRow: (c) => (
      <>
        <IconOrThumbnail
          thumbnailUrl={c.square_image_url ?? c.image_url ?? null}
          icon={<FolderTreeIcon />}
        />
        <span className="flex-1 truncate">{c.pretty_name}</span>
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Collection>({
    key: 'collections',
    headingKey: 'admin.nav.collections',
    subject: Subject.Collection,
    position: 160,
    fetch: (search, limit) =>
      adminClient.collections.list({ name_cont: search, limit, sort: 'name' }).then((r) => r.data),
    getKey: (c) => c.id,
    getRoute: (c, storeId) => ({ to: `/${storeId}/products/collections/${c.id}` }),
    renderRow: (c) => (
      <>
        <IconOrThumbnail
          thumbnailUrl={c.square_image_url ?? c.image_url ?? null}
          icon={<LayersIcon />}
        />
        <span className="flex-1 truncate">{c.name}</span>
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Order>({
    key: 'orders',
    headingKey: 'admin.nav.orders',
    subject: Subject.Order,
    position: 200,
    fetch: (search, limit) => adminClient.orders.list({ search, limit }).then((r) => r.data),
    getKey: (o) => o.id,
    getRoute: (o, storeId) => ({ to: `/${storeId}/orders/${o.id}` }),
    renderRow: (o) => (
      <>
        <ShoppingCartIcon />
        <span className="flex-1 truncate">
          <span className="font-mono">{o.number}</span>
          {o.email && <span className="ml-2 text-muted-foreground">{o.email}</span>}
        </span>
        {o.payment_status && <StatusBadge status={o.payment_status} />}
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Customer>({
    key: 'customers',
    headingKey: 'admin.nav.customers',
    subject: Subject.Customer,
    position: 300,
    fetch: (search, limit) => adminClient.customers.list({ search, limit }).then((r) => r.data),
    getKey: (c) => c.id,
    getRoute: (c, storeId) => ({ to: `/${storeId}/customers/${c.id}` }),
    renderRow: (c) => (
      <>
        <UsersIcon />
        <span className="flex-1 truncate">
          {c.full_name || c.email}
          {c.full_name && <span className="ml-2 text-muted-foreground">{c.email}</span>}
        </span>
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Promotion>({
    key: 'promotions',
    headingKey: 'admin.nav.promotions',
    subject: Subject.Promotion,
    position: 400,
    // No backend `search` scope — match name or coupon code via a Ransack
    // `cont` predicate (both columns are whitelisted on Spree::Promotion).
    fetch: (query, limit) =>
      adminClient.promotions.list({ name_or_code_cont: query, limit }).then((r) => r.data),
    getKey: (p) => p.id,
    getRoute: (p, storeId) => ({ to: `/${storeId}/promotions/${p.id}` }),
    renderRow: (p) => (
      <>
        <TicketPercentIcon />
        <span className="flex-1 truncate">{p.name}</span>
        {p.code && (
          <span className="ml-2 shrink-0 font-mono text-xs text-muted-foreground">{p.code}</span>
        )}
      </>
    ),
  }),
)

/**
 * A result row's thumbnail, falling back to the resource's own icon.
 *
 * Deliberately not `Thumbnail`: search results without an image show a bare
 * glyph rather than an empty framed box, so a category or a page does not look
 * like a product whose photo failed to load.
 */
function IconOrThumbnail({ thumbnailUrl, icon }: { thumbnailUrl: string | null; icon: ReactNode }) {
  if (!thumbnailUrl) return icon
  return (
    <img
      src={thumbnailUrl}
      alt=""
      className="size-5 shrink-0 rounded object-cover"
      loading="lazy"
    />
  )
}
