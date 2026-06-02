import type { Channel } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import { RadioTowerIcon } from 'lucide-react'

defineTable<Channel>('channels', {
  title: 'Channels',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <RadioTowerIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No channels yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      render: (channel) => (
        <ResourceNameCell
          id={channel.id}
          dataAttr="data-channel-id"
          name={channel.name}
          secondary={channel.code}
        />
      ),
    },
    {
      key: 'code',
      label: 'Code',
      sortable: true,
      filterable: true,
      default: true,
      className: 'text-sm text-muted-foreground',
      render: (channel) => channel.code,
    },
    {
      key: 'active',
      label: 'Status',
      sortable: false,
      filterable: true,
      filterType: 'boolean',
      default: true,
      render: (channel) => <ActiveBadge active={channel.active} />,
    },
  ],
})
