import type {
  Category,
  Collection,
  Company,
  Customer,
  CustomerGroup,
  Order,
  Product,
  Promotion,
  Seller,
} from '@spree/admin-sdk'
import { adminClient, defineSearchEntry, Subject, searchRegistry } from '@spree/dashboard-core'
import { StatusBadge, Thumbnail } from '@spree/dashboard-ui'
import {
  Building2Icon,
  FolderTreeIcon,
  LayersIcon,
  ShoppingCartIcon,
  StoreIcon,
  TicketPercentIcon,
  UserIcon,
  UsersRoundIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

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
    // Two lines, as a product row is rarely identifiable by name alone: near
    // duplicates ("… 18V" / "… 25V") differ only in stock and price.
    renderRow: (p) => (
      <>
        <Thumbnail
          src={p.primary_media?.mini_url ?? p.thumbnail_url}
          size="sm"
          className="self-start"
        />
        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
          <span className="flex items-center gap-2">
            <span className="truncate">{p.name}</span>
            <StatusBadge status={p.status} />
          </span>
          <ProductMeta product={p} />
        </span>
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
        <Thumbnail
          src={c.square_image_url ?? c.image_url}
          size="xs"
          fallback={<FolderTreeIcon />}
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
        <Thumbnail src={c.square_image_url ?? c.image_url} size="xs" fallback={<LayersIcon />} />
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
        <Thumbnail size="xs" fallback={<ShoppingCartIcon />} />
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
        <Thumbnail size="xs" shape="circle" fallback={<UserIcon />} />
        <span className="flex-1 truncate">
          {c.full_name || c.email}
          {c.full_name && <span className="ml-2 text-muted-foreground">{c.email}</span>}
        </span>
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<CustomerGroup>({
    key: 'customer_groups',
    headingKey: 'admin.nav.customer_groups',
    subject: Subject.CustomerGroup,
    position: 310,
    fetch: (search, limit) =>
      adminClient.customerGroups
        .list({ name_cont: search, limit, sort: 'name' })
        .then((r) => r.data),
    getKey: (g) => g.id,
    // Groups have no detail page — they are edited in a sheet on the groups
    // page, which `?edit=` opens directly.
    getRoute: (g, storeId) => ({ to: `/${storeId}/customers/groups`, search: { edit: g.id } }),
    renderRow: (g) => (
      <>
        <Thumbnail size="xs" fallback={<UsersRoundIcon />} />
        <span className="flex-1 truncate">{g.name}</span>
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Company>({
    key: 'companies',
    headingKey: 'admin.nav.companies',
    subject: Subject.Company,
    position: 320,
    fetch: (search, limit) =>
      adminClient.companies.list({ name_cont: search, limit, sort: 'name' }).then((r) => r.data),
    getKey: (c) => c.id,
    getRoute: (c, storeId) => ({ to: `/${storeId}/companies/${c.id}` }),
    renderRow: (c) => (
      <>
        <Thumbnail size="xs" fallback={<Building2Icon />} />
        <span className="flex-1 truncate">{c.name}</span>
      </>
    ),
  }),
)

searchRegistry.add(
  defineSearchEntry<Seller>({
    key: 'sellers',
    headingKey: 'admin.nav.sellers',
    subject: Subject.Seller,
    position: 330,
    fetch: (search, limit) =>
      adminClient.sellers.list({ name_cont: search, limit, sort: 'name' }).then((r) => r.data),
    getKey: (s) => s.id,
    getRoute: (s, storeId) => ({ to: `/${storeId}/sellers/${s.id}` }),
    renderRow: (s) => (
      <>
        <Thumbnail src={s.square_logo_url ?? s.logo_url} size="xs" fallback={<StoreIcon />} />
        <span className="flex-1 truncate">{s.name}</span>
        <StatusBadge status={s.status} />
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
        <Thumbnail size="xs" fallback={<TicketPercentIcon />} />
        <span className="flex-1 truncate">{p.name}</span>
        {p.code && (
          <span className="ml-2 shrink-0 font-mono text-xs text-muted-foreground">{p.code}</span>
        )}
      </>
    ),
  }),
)

/** Stock and price beneath a product's name — the pair that tells near-identical
 *  variants apart. Renders nothing when neither is known. */
function ProductMeta({ product }: { product: Product }) {
  const { t } = useTranslation()
  const stock = product.in_stock
    ? t('admin.pages.products.inventory.in_stock_short')
    : product.backorderable
      ? t('admin.pages.products.inventory.on_backorder')
      : t('admin.pages.products.inventory.out_of_stock')
  const price = product.price?.display_amount

  return (
    <span className="truncate text-muted-foreground text-xs">
      {price ? `${stock} • ${price}` : stock}
    </span>
  )
}
