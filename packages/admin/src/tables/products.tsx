import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { PackageIcon } from 'lucide-react'
import { RelativeTime } from '@/components/spree/relative-time'
import { TagList } from '@/components/spree/tag-list'
import { StatusBadge } from '@/components/ui/badge'
import { categoryAutocompleteProps } from '@/hooks/use-categories'
import { formatPrice } from '@/lib/formatters'
import { Subject } from '@/lib/permissions'
import { defineTable } from '@/lib/table-registry'

defineTable('products', {
  title: i18n.t('admin.nav.products'),
  searchParam: 'multi_search',
  searchPlaceholder: i18n.t('admin.common.search_placeholder'),
  defaultSort: { field: 'updated_at', direction: 'desc' },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.common.no_results'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (product) => (
        <Link
          to={'/$storeId/products/$productId' as string}
          params={{ productId: product.id }}
          className="flex items-center gap-3 no-underline"
        >
          <div className="flex size-10 shrink-0 items-center justify-center rounded-lg border border-border bg-muted overflow-hidden">
            {product.thumbnail_url ? (
              <img
                src={product.thumbnail_url}
                alt={product.name}
                className="size-full object-cover"
              />
            ) : (
              <PackageIcon className="size-4 text-muted-foreground" />
            )}
          </div>
          <div className="min-w-0">
            <div className="truncate font-medium text-foreground">{product.name}</div>
          </div>
        </Link>
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'draft', label: i18n.t('admin.pages.products.status_options.draft') },
        { value: 'active', label: i18n.t('admin.pages.products.status_options.active') },
        { value: 'archived', label: i18n.t('admin.pages.products.status_options.archived') },
      ],
      render: (product) => <StatusBadge status={product.status} />,
    },
    {
      key: 'inventory',
      label: i18n.t('admin.pages.products.section_inventory'),
      sortable: false,
      filterable: false,
      default: true,
      render: (product) => {
        const variantCount = product.variant_count

        const inventoryStatus =
          !product.in_stock && !product.backorderable ? (
            <span className="text-sm text-destructive">
              {i18n.t('admin.pages.products.inventory.out_of_stock')}
            </span>
          ) : product.backorderable && !product.in_stock ? (
            <span className="text-sm text-muted-foreground">
              {i18n.t('admin.pages.products.inventory.on_backorder')}
            </span>
          ) : (
            <span className="text-sm text-muted-foreground">
              {i18n.t('admin.pages.products.inventory.in_stock', { count: product.total_on_hand })}
            </span>
          )

        return (
          <span>
            {inventoryStatus}
            {variantCount > 1 ? (
              <>
                &nbsp; &#8211; &nbsp;
                <span className="text-sm text-muted-foreground">
                  {i18n.t('admin.pages.products.variants', { count: variantCount })}
                </span>
              </>
            ) : (
              ''
            )}
          </span>
        )
      },
    },
    {
      key: 'sku',
      label: 'SKU',
      sortable: false,
      filterable: true,
      default: false,
      ransackAttribute: 'master_sku',
      className: 'text-sm text-muted-foreground',
      render: (product) => product.sku ?? '—',
    },
    {
      key: 'price',
      label: 'Price',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'number',
      ransackAttribute: 'master_price',
      className: 'text-right tabular-nums whitespace-nowrap',
      render: (product) => formatPrice(product.price),
    },
    {
      key: 'tags',
      label: i18n.t('admin.fields.product.tags.label'),
      sortable: false,
      filterable: true,
      filterType: 'tags',
      taggableType: Subject.Product,
      default: false,
      render: (product) => <TagList tags={product.tags} />,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (product) => <RelativeTime iso={product.created_at} />,
    },
    {
      key: 'updated_at',
      label: i18n.t('admin.fields.updated_at.label'),
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (product) => <RelativeTime iso={product.updated_at} />,
    },
    {
      key: 'in_stock',
      label: 'In Stock',
      filterable: true,
      filterType: 'boolean',
      displayable: false,
      default: false,
    },
    // Filter-only — Ransack joins through `products.taxons`, so the predicate
    // emitted is `taxons_id_in`. We don't render a categories cell on the
    // index to avoid expanding categories on every list refetch; users can
    // see attached categories on the product edit page.
    {
      key: 'categories',
      label: i18n.t('admin.fields.product.category_ids.label'),
      filterable: true,
      filterType: 'resource',
      filterResource: categoryAutocompleteProps('products-table-category-filter'),
      ransackAttribute: 'taxons_id',
      displayable: false,
      default: false,
    },
  ],
})
