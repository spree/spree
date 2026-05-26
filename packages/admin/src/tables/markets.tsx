import type { Market } from '@spree/admin-sdk'
import { GlobeIcon } from 'lucide-react'
import { LocaleLabel } from '@/components/spree/locale-select'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { ActiveBadge, Badge } from '@/components/ui/badge'
import { defineTable } from '@/lib/table-registry'

defineTable<Market>('markets', {
  title: 'Markets',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <GlobeIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No markets yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      render: (market) => (
        <ResourceNameCell
          id={market.id}
          dataAttr="data-market-id"
          name={market.name}
          secondary={market.country_isos.length > 0 ? market.country_isos.join(', ') : undefined}
        />
      ),
    },
    {
      key: 'currency',
      label: 'Currency',
      sortable: true,
      default: true,
      render: (market) => <Badge variant="outline">{market.currency}</Badge>,
    },
    {
      key: 'default_locale',
      label: 'Default locale',
      sortable: true,
      default: true,
      render: (market) => <LocaleLabel code={market.default_locale} />,
    },
    {
      key: 'tax_inclusive',
      label: 'Tax',
      default: true,
      render: (market) => (
        <ActiveBadge
          active={market.tax_inclusive}
          activeLabel="Inclusive"
          inactiveLabel="Exclusive"
        />
      ),
    },
    {
      key: 'default',
      label: 'Default',
      default: true,
      render: (market) => (
        <ActiveBadge active={market.default} activeLabel="Default" dashWhenInactive />
      ),
    },
  ],
})
