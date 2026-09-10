import type { StockLevel } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, ResourceNameCell, Thumbnail } from '@spree/dashboard-ui'
import { PackageIcon, WarehouseIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { CountCell, IncomingCell, OnHandCell } from '../components/spree/inventory-cells'
import { stockLocationAutocompleteProps } from '../hooks/use-stock-levels'

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
      render: (level) => (
        <div className="flex items-center gap-3">
          <Thumbnail src={level.thumbnail_url} fallback={<PackageIcon />} />
          <ResourceNameCell
            id={level.product_id ?? ''}
            dataAttr={level.product_id ? 'data-stock-level-product-id' : undefined}
            name={level.variant_name ?? '—'}
            secondary={
              level.options_text ? (
                <Badge variant="secondary" className="font-normal">
                  {level.options_text}
                </Badge>
              ) : null
            }
          />
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
      className: 'text-right',
      render: (level) => <CountCell value={level.allocated_count} />,
    },
    {
      key: 'reserved_count',
      label: i18n.t('admin.stock_levels.columns.reserved'),
      sortable: true,
      default: true,
      className: 'text-right',
      render: (level) => <CountCell value={level.reserved_count} />,
    },
    {
      key: 'available',
      label: i18n.t('admin.stock_levels.columns.available'),
      default: true,
      className: 'text-right',
      // On hand minus committed minus reserved — what a customer can still
      // buy from this shelf. Negative when it is oversold, which is worth
      // seeing rather than hiding.
      render: (level) => <CountCell value={level.available_count - level.reserved_count} />,
    },
    {
      key: 'count_on_hand',
      label: i18n.t('admin.stock_levels.columns.on_hand'),
      sortable: true,
      filterable: true,
      filterType: 'number',
      default: true,
      className: 'text-right',
      render: (level) => <OnHandCell level={level} />,
    },
    {
      key: 'incoming_count',
      label: i18n.t('admin.stock_levels.columns.incoming'),
      sortable: true,
      default: true,
      className: 'text-right',
      render: (level) => <IncomingCell level={level} />,
    },
  ],
})
