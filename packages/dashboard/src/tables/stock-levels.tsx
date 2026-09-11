import type { StockLevel } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, Thumbnail } from '@spree/dashboard-ui'
import { PackageIcon, WarehouseIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { IncomingCell, OnHandCell } from '../components/spree/inventory-cells'
import { stockLocationAutocompleteProps } from '../hooks/use-stock-levels'

/** The product name, with the variant's options under it when it has any. */
function ProductLabel({ level }: { level: StockLevel }) {
  return (
    <div className="min-w-0">
      <div className="truncate font-medium text-foreground">{level.variant_name ?? '—'}</div>
      {level.options_text && (
        <Badge variant="secondary" className="font-normal">
          {level.options_text}
        </Badge>
      )}
    </div>
  )
}

// Every figure is a column on the row: on hand and committed were always
// stored, reserved and incoming are counters kept by the workflows that
// change them, and available is the difference. Nothing is summed here.
defineTable<StockLevel>('stock-levels', {
  title: i18n.t('admin.stock_levels.title'),
  description: i18n.t('admin.table_descriptions.stock_levels'),
  docsPath: 'manage-products/stock-levels',
  searchParam: 'variant_sku_or_variant_product_name_cont',
  searchPlaceholder: i18n.t('admin.stock_levels.table.search_placeholder'),
  emptyIcon: <WarehouseIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.stock_levels.table.empty'),
  columns: [
    {
      key: 'product',
      label: i18n.t('admin.stock_levels.columns.product'),
      default: true,
      // Image and text are one target: a merchant aiming at the picture of the
      // thing they want means the thing they want. `Link` rather than the row
      // bridge so the whole cell also middle-clicks and copies as a URL.
      render: (level) =>
        level.product_id ? (
          <Link
            to={'/$storeId/products/$productId' as string}
            params={{ productId: level.product_id }}
            className="flex items-center gap-3 no-underline"
          >
            <Thumbnail src={level.thumbnail_url} fallback={<PackageIcon />} />
            <ProductLabel level={level} />
          </Link>
        ) : (
          <div className="flex items-center gap-3">
            <Thumbnail src={level.thumbnail_url} fallback={<PackageIcon />} />
            <ProductLabel level={level} />
          </div>
        ),
    },
    {
      key: 'sku',
      label: i18n.t('admin.stock_levels.columns.sku'),
      default: true,
      className: 'text-sm text-muted-foreground',
      render: (level) => level.variant_sku || i18n.t('admin.stock_levels.no_sku'),
    },
    {
      key: 'stock_location',
      label: i18n.t('admin.stock_levels.columns.location'),
      filterable: true,
      filterType: 'resource',
      filterResource: stockLocationAutocompleteProps('stock-levels-table-location-filter'),
      ransackAttribute: 'stock_location_id',
      default: true,
      render: (level) => level.stock_location_name ?? '—',
    },
    {
      key: 'allocated_count',
      label: i18n.t('admin.stock_levels.columns.committed'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (level) => level.allocated_count,
    },
    {
      key: 'reserved_count',
      label: i18n.t('admin.stock_levels.columns.reserved'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (level) => level.reserved_count,
    },
    {
      key: 'available',
      label: i18n.t('admin.stock_levels.columns.available'),
      default: true,
      className: 'text-right tabular-nums',
      // On hand minus committed minus reserved, computed by the API so the
      // page and the `in_stock` filter agree on one definition. Negative when
      // it is oversold, which is worth seeing rather than hiding.
      render: (level) => level.purchasable_count,
    },
    {
      key: 'count_on_hand',
      label: i18n.t('admin.stock_levels.columns.on_hand'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (level) => <OnHandCell level={level} />,
    },
    {
      key: 'incoming_count',
      label: i18n.t('admin.stock_levels.columns.incoming'),
      sortable: true,
      default: true,
      className: 'text-right tabular-nums',
      render: (level) => <IncomingCell level={level} />,
    },
    // The three questions a merchant brings to this list. Each is a scope,
    // not a predicate on a column: "can I sell it?" is on hand minus
    // committed minus reserved, which no single column answers. Filter-only —
    // the figures they read are already columns of their own.
    {
      key: 'in_stock',
      label: i18n.t('admin.stock_levels.columns.availability'),
      ransackAttribute: 'in_stock',
      ransackScope: true,
      displayable: false,
      filterable: true,
      filterType: 'boolean',
      booleanLabels: {
        true: i18n.t('admin.stock_levels.filters.in_stock'),
        false: i18n.t('admin.stock_levels.filters.out_of_stock'),
      },
      quickFilter: true,
    },
    {
      key: 'with_incoming',
      label: i18n.t('admin.stock_levels.columns.incoming'),
      ransackAttribute: 'with_incoming',
      ransackScope: true,
      displayable: false,
      filterable: true,
      filterType: 'boolean',
      booleanLabels: {
        true: i18n.t('admin.stock_levels.filters.has_incoming'),
        false: i18n.t('admin.stock_levels.filters.no_incoming'),
      },
      quickFilter: true,
    },
    {
      key: 'with_reserved',
      label: i18n.t('admin.stock_levels.columns.reserved'),
      ransackAttribute: 'with_reserved',
      ransackScope: true,
      displayable: false,
      filterable: true,
      filterType: 'boolean',
      booleanLabels: {
        true: i18n.t('admin.stock_levels.filters.has_reserved'),
        false: i18n.t('admin.stock_levels.filters.no_reserved'),
      },
      quickFilter: true,
    },
  ],
})
