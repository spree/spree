import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell, StatusBadge, Thumbnail } from '@spree/dashboard-ui'
import { TagIcon } from '@spree/dashboard-ui/icons'
import type { Variant } from '@spree/seller-sdk'
import i18n from 'i18next'

/** The same vocabulary a product uses, so the two never read differently. */
const OFFER_STATUSES = ['active', 'draft', 'proposed', 'rejected', 'archived'] as const

defineTable<Variant>('seller-offers', {
  title: i18n.t('offers.title'),
  // Searches the SKU rather than the product name: the product is the
  // marketplace's and a seller finds their own row by what they called it.
  searchParam: 'sku_cont',
  searchPlaceholder: i18n.t('offers.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <TagIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('offers.empty'),
  columns: [
    {
      key: 'product',
      label: i18n.t('offers.columns.product'),
      default: true,
      render: (offer) => (
        <div className="flex items-center gap-3">
          <Thumbnail src={offer.product?.thumbnail_url} alt={offer.product?.name ?? ''} />
          <ResourceNameCell
            id={offer.id}
            dataAttr="data-offer-id"
            name={offer.product?.name ?? offer.options_text ?? offer.sku ?? ''}
          />
        </div>
      ),
    },
    {
      key: 'options_text',
      label: i18n.t('offers.columns.options'),
      default: true,
      render: (offer) => offer.options_text || '—',
    },
    {
      key: 'sku',
      label: i18n.t('offers.columns.sku'),
      sortable: true,
      default: true,
      render: (offer) => offer.sku || '—',
    },
    {
      key: 'status',
      label: i18n.t('offers.columns.status'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: OFFER_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`offers.statuses.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (offer) => (
        <StatusBadge status={offer.status} label={i18n.t(`offers.statuses.${offer.status}`)} />
      ),
    },
    {
      key: 'price',
      label: i18n.t('offers.columns.price'),
      default: true,
      render: (offer) => offer.price?.display_amount ?? '—',
    },
    {
      key: 'stock',
      label: i18n.t('offers.columns.stock'),
      default: true,
      render: (offer) => (offer.total_on_hand == null ? '—' : String(offer.total_on_hand)),
    },
  ],
})
