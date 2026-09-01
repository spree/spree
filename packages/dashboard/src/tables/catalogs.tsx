import type { Catalog } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
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
      // The filter says what the rows say. Left to the generic Yes/No, a
      // Status control would answer a question the column never asked.
      booleanLabels: {
        true: i18n.t('admin.common.active'),
        false: i18n.t('admin.common.inactive'),
      },
      // Surfaced beside the search the way a price list's status is: which
      // agreements are live is the first thing asked of this list. A catalog
      // is only ever active or not — it has no dates, so nothing to schedule.
      quickFilter: true,
      default: true,
      // Named rather than left to the Yes/No default: the column asks whether
      // the agreement applies, and "Active" is what that answer is called
      // everywhere else it appears.
      render: (catalog) => (
        <ActiveBadge
          active={catalog.active}
          activeLabel={i18n.t('admin.common.active')}
          inactiveLabel={i18n.t('admin.common.inactive')}
        />
      ),
    },
    {
      key: 'pricing_strategy',
      label: i18n.t('admin.fields.catalog.pricing_mode.label'),
      default: true,
      // What the agreement charges, in a word. `base` is the one worth
      // reading differently: the catalog decides visibility and leaves the
      // price alone, so it is not a pricing strategy so much as the absence
      // of one.
      render: (catalog) => (
        <Badge variant={catalog.pricing_strategy === 'base' ? 'outline' : 'secondary'}>
          {i18n.t(`admin.fields.catalog.pricing_mode.${catalog.pricing_strategy}`)}
        </Badge>
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
