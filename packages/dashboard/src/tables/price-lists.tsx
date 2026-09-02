import type { PriceList } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell } from '@spree/dashboard-ui'
import { TagsIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { PriceListStatusBadge } from '../components/spree/price-list-editors/status-badge'

defineTable<PriceList>('price-lists', {
  title: i18n.t('admin.nav.price_lists'),
  description: i18n.t('admin.table_descriptions.price_lists'),
  docsPath: 'manage-products/price-lists',
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.common.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <TagsIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.common.no_results'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (list) => (
        <ResourceNameCell
          id={list.id}
          dataAttr="data-price-list-id"
          name={list.name}
          secondary={list.description ?? undefined}
        />
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'draft', label: i18n.t('admin.fields.price_list.status.draft') },
        { value: 'active', label: i18n.t('admin.fields.price_list.status.active') },
        { value: 'scheduled', label: i18n.t('admin.fields.price_list.status.scheduled') },
        { value: 'inactive', label: i18n.t('admin.fields.price_list.status.inactive') },
      ],
      quickFilter: true,
      default: true,
      // Filters the stored `status`, which is the only thing the API can
      // filter on — `currently_active?` is a Ruby predicate, not a ransackable
      // attribute. The badge shows a `scheduled` list that is within its dates
      // as Active, so filtering by Active omits those rows. Closing that gap
      // needs an effective-status scope server-side; until then the filter
      // names the stored value and the badge names the effective one.
      render: (list) => <PriceListStatusBadge priceList={list} />,
    },
    {
      key: 'products_count',
      label: i18n.t('admin.fields.products_count.label'),
      default: true,
      render: (list) => list.products_count,
    },
    {
      key: 'prices_count',
      label: i18n.t('admin.fields.prices_count.label'),
      default: true,
      render: (list) => list.prices_count,
    },
    {
      key: 'starts_at',
      label: i18n.t('admin.fields.starts_at.label'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: false,
      render: (list) => (list.starts_at ? new Date(list.starts_at).toLocaleDateString() : '—'),
    },
    {
      key: 'ends_at',
      label: i18n.t('admin.fields.ends_at.label'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: false,
      render: (list) => (list.ends_at ? new Date(list.ends_at).toLocaleDateString() : '—'),
    },
  ],
})
