import type { OauthApplication } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import { PlugIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { ScopeList } from '../components/spree/api-keys/api-key-table'

defineTable<OauthApplication>('oauth-applications', {
  title: i18n.t('admin.settings_nav.items.connected_apps'),
  description: i18n.t('admin.pages.settings.connected_apps.subtitle'),
  emptyIcon: <PlugIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.pages.settings.connected_apps.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.pages.settings.connected_apps.table.name'),
      default: true,
      render: (application) => <ResourceNameCell id={application.id} name={application.name} />,
    },
    {
      key: 'connected',
      label: i18n.t('admin.pages.settings.connected_apps.table.status'),
      default: true,
      // A registration nobody connected and one whose access was revoked
      // both show no permissions, so without this the row looks unchanged
      // after a merchant presses Revoke.
      render: (application) =>
        application.connected ? (
          <StatusBadge
            status="connected"
            tone="success"
            label={i18n.t('admin.pages.settings.connected_apps.status.connected')}
          />
        ) : (
          <StatusBadge
            status="not_connected"
            tone="neutral"
            label={i18n.t('admin.pages.settings.connected_apps.status.not_connected')}
          />
        ),
    },
    {
      key: 'scopes',
      label: i18n.t('admin.pages.settings.connected_apps.table.access'),
      default: true,
      render: (application) => <ScopeList scopes={application.scopes} />,
    },
    {
      key: 'authorized_by',
      label: i18n.t('admin.pages.settings.connected_apps.table.authorized_by'),
      default: true,
      render: (application) =>
        application.authorized_by ? (
          <span className="flex flex-col">
            <span>{application.authorized_by}</span>
            <span className="text-muted-foreground text-xs">
              <RelativeTime iso={application.authorized_at} />
            </span>
          </span>
        ) : (
          <span className="text-muted-foreground">—</span>
        ),
    },
    {
      key: 'last_authorized_at',
      label: i18n.t('admin.pages.settings.connected_apps.table.last_authorized'),
      default: true,
      render: (application) => <RelativeTime iso={application.last_authorized_at} />,
    },
  ],
})
