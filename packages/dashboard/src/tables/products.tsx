import type { Channel } from '@spree/admin-sdk'
import { PRODUCT_STATUSES } from '@spree/core'
import { defineTable, formatPrice, ProductStockSummary } from '@spree/dashboard-core'
import { ProductIdentity, StatusBadge, TagList } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { categoryAutocompleteProps } from '../hooks/use-categories'
import { channelAutocompleteProps } from '../hooks/use-channels'
import { productTypeAutocompleteProps } from '../hooks/use-product-types'
import { sellerAutocompleteProps } from '../hooks/use-sellers'

defineTable('products', {
  docsPath: 'products/creating-products',
  description: i18n.t('admin.table_descriptions.products'),
  title: i18n.t('admin.nav.products'),
  searchParam: 'search',
  searchPlaceholder: i18n.t('admin.common.search_placeholder'),
  defaultSort: { field: 'updated_at', direction: 'desc' },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.common.no_results'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (product) => (
        <ProductIdentity
          name={product.name}
          thumbnailUrl={product.thumbnail_url}
          render={
            <Link
              to={'/$storeId/products/$productId' as string}
              params={{ productId: product.id }}
            />
          }
        />
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'enum',
      quickFilter: true,
      // Every status, review ones included: an operator filters to what is in
      // review even though only the bulk action is limited to the three it
      // may set.
      filterOptions: PRODUCT_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`admin.pages.products.status_options.${status}`),
      })),
      render: (product) => (
        <StatusBadge
          status={product.status}
          label={i18n.t(`admin.pages.products.status_options.${product.status}`, {
            defaultValue: product.status,
          })}
        />
      ),
    },
    {
      key: 'inventory',
      label: i18n.t('admin.pages.products.section_inventory'),
      sortable: false,
      filterable: false,
      default: true,
      render: (product) => <ProductStockSummary product={product} />,
    },
    {
      key: 'sku',
      label: i18n.t('admin.products.columns.sku'),
      sortable: false,
      // Not filterable: the search box already matches SKUs, and matches them
      // better — it searches every variant's, where this filtered only the
      // default variant's.
      default: false,
      className: 'text-base text-muted-foreground',
      render: (product) => product.sku ?? '—',
    },
    {
      key: 'price',
      label: i18n.t('admin.products.columns.price'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'number',
      className: 'text-right tabular-nums whitespace-nowrap',
      render: (product) => formatPrice(product.price),
    },
    {
      key: 'tags',
      label: i18n.t('admin.fields.product.tags.label'),
      sortable: false,
      filterable: true,
      filterType: 'tags',
      taggableType: 'product',
      default: false,
      render: (product) => <TagList tags={product.tags} />,
    },
    // No `in_stock` filter. `in_stock` is a Ransack *scope* on Spree::Product,
    // not a ransackable attribute, so any `in_stock_*` predicate is dropped
    // server-side without error — the list comes back unfiltered while the
    // control says otherwise. The scope also cannot express the negative:
    // `in_stock('0')` returns everything, and "out of stock" is a second,
    // separate scope. Restoring this needs `filtersToRansack` to learn how to
    // emit a bare scope key, which is a change to the filter contract rather
    // than a column flag.
    // Filter-only — Ransack joins through `products.categories`, so the
    // predicate emitted is `categories_id_in`. We don't render a categories cell on the
    // index to avoid expanding categories on every list refetch; users can
    // see attached categories on the product edit page.
    // On a marketplace this list holds the operator's own products and every
    // seller's together, so a row has to say which it is — shown by default
    // for the same reason the stock-locations list shows it. A dash means the
    // product is the marketplace's own, matching how the other columns render
    // an absent value.
    {
      key: 'seller',
      label: i18n.t('admin.fields.product.seller.label'),
      filterable: true,
      filterType: 'resource',
      filterResource: sellerAutocompleteProps('products-table-seller-filter'),
      ransackAttribute: 'seller_id',
      default: true,
      render: (product) =>
        product.seller_id ? (
          <Link
            to={'/$storeId/sellers/$sellerId' as string}
            params={{ sellerId: product.seller_id }}
            className="no-underline"
          >
            {product.seller_name}
          </Link>
        ) : (
          '—'
        ),
    },
    {
      key: 'categories',
      label: i18n.t('admin.fields.product.category_ids.label'),
      filterable: true,
      filterType: 'resource',
      filterResource: categoryAutocompleteProps('products-table-category-filter'),
      ransackAttribute: 'categories_id',
      displayable: false,
      default: false,
    },
    {
      key: 'channels',
      label: i18n.t('admin.fields.product.channels.label'),
      sortable: false,
      filterable: true,
      filterType: 'resource',
      filterResource: channelAutocompleteProps(),
      ransackAttribute: 'channels_id',
      default: false,
      render: (product) => product.channels?.map((c: Channel) => c.name).join(', ') ?? '—',
    },
    {
      key: 'product_type',
      label: i18n.t('admin.fields.product.product_type_id.label'),
      sortable: false,
      filterable: true,
      filterType: 'resource',
      // Filters through the association (`product_type_id_in`), matching how
      // categories and channels filter — product_type_id is not a ransackable
      // attribute on Product, but product_type is a ransackable association.
      filterResource: productTypeAutocompleteProps('products-table-product-type-filter'),
      ransackAttribute: 'product_type_id',
      // Requested only while the column is on — ResourceTable unions the
      // expands of visible columns into the list request.
      expand: 'product_type',
      default: false,
      render: (product) => product.product_type?.name ?? '—',
    },
  ],
})
