import type { Catalog } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { BookOpenIcon } from 'lucide-react'

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
      label: i18n.t('admin.fields.active.label'),
      default: true,
      render: (catalog) =>
        catalog.active ? (
          <Badge variant="outline">{i18n.t('admin.common.active')}</Badge>
        ) : (
          <Badge variant="secondary">{i18n.t('admin.common.inactive')}</Badge>
        ),
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
