import type { Channel } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { RadioTowerIcon } from 'lucide-react'

defineTable<Channel>('channels', {
  title: i18n.t('admin.pages.channels.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.common.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <RadioTowerIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.pages.channels.empty_message'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
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
      label: i18n.t('admin.fields.channel.code.label'),
      sortable: true,
      filterable: true,
      default: true,
      className: 'text-sm text-muted-foreground',
      render: (channel) => channel.code,
    },
    {
      key: 'active',
      label: i18n.t('admin.fields.status.label'),
      sortable: false,
      filterable: true,
      filterType: 'boolean',
      default: true,
      render: (channel) => <ActiveBadge active={channel.active} />,
    },
    {
      key: 'default',
      label: i18n.t('admin.fields.channel.default.label'),
      sortable: true,
      filterable: true,
      filterType: 'boolean',
      default: true,
      render: (channel) => (
        <ActiveBadge
          active={channel.default}
          activeLabel={i18n.t('admin.common.yes')}
          dashWhenInactive
        />
      ),
    },
  ],
})
