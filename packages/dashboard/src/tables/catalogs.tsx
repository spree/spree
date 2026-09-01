import type { Catalog } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import { BookOpenIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

defineTable<Catalog>('catalogs', {
  title: i18n.t('admin.nav.catalogs'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.catalogs.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <BookOpenIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.catalogs.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (catalog) => (
        <ResourceNameCell
          id={catalog.id}
          dataAttr="data-catalog-id"
          name={catalog.name}
          secondary={catalog.description ?? undefined}
        />
      ),
    },
    {
      key: 'active',
      label: i18n.t('admin.fields.status.label'),
      filterable: true,
      filterType: 'boolean',
      // Surfaced beside the search the way a price list's status is: which
      // agreements are live is the first thing asked of this list. A catalog
      // is only ever active or not — it has no dates, so nothing to schedule.
      quickFilter: true,
      default: true,
      render: (catalog) => <ActiveBadge active={catalog.active} />,
    },
    {
      key: 'products_count',
      label: i18n.t('admin.catalogs.products_column'),
      default: true,
      render: (catalog) => catalog.products_count,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (catalog) => <RelativeTime iso={catalog.created_at} />,
    },
  ],
})
