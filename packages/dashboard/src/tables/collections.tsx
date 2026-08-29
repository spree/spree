import type { Collection } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { LayersIcon } from 'lucide-react'
import { sortOrderLabelKey } from '../schemas/collection'

defineTable<Collection>('collections', {
  title: i18n.t('admin.collections.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.collections.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <LayersIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.collections.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (collection) => (
        <ResourceNameCell
          id={collection.id}
          dataAttr="data-collection-id"
          name={collection.name}
          secondary={collection.permalink}
        />
      ),
    },
    {
      key: 'automatic',
      label: i18n.t('admin.collections.columns.membership'),
      filterable: true,
      filterType: 'boolean',
      default: true,
      render: (collection) => (
        <Badge variant="outline">
          {collection.automatic
            ? i18n.t('admin.collections.membership.automatic')
            : i18n.t('admin.collections.membership.manual')}
        </Badge>
      ),
    },
    {
      key: 'sort_order',
      label: i18n.t('admin.collections.columns.sort_order'),
      default: true,
      render: (collection) => {
        // `sort_order` is an open string on the wire, so a value this build
        // doesn't know would otherwise render its raw translation key.
        const value = collection.sort_order ?? 'manual'
        const key = sortOrderLabelKey(value)
        return i18n.exists(key) ? i18n.t(key) : value
      },
    },
    {
      key: 'products_count',
      label: i18n.t('admin.collections.columns.products_count'),
      default: true,
      render: (collection) => collection.products_count ?? 0,
    },
  ],
})
