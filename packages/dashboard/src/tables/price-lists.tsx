import type { PriceList } from '@spree/admin-sdk'
import i18n from 'i18next'
import { TagsIcon } from 'lucide-react'
import { PriceListStatusBadge } from '@/components/spree/price-list-editors/status-badge'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { defineTable } from '@/lib/table-registry'

defineTable<PriceList>('price-lists', {
  title: i18n.t('admin.nav.price_lists'),
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
      filterable: true,
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
      default: true,
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
