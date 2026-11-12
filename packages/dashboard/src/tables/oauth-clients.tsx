import type { OauthApplication } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { CopyToClipboardButton, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import { KeyRoundIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

// The developer's view of the same records the merchant connects: the raw
// registration, including the identifiers a client is configured with.
defineTable<OauthApplication>('oauth-clients', {
  title: i18n.t('admin.pages.settings.oauth_clients.title'),
  description: i18n.t('admin.pages.settings.oauth_clients.subtitle'),
  emptyIcon: <KeyRoundIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.pages.settings.oauth_clients.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.oauth_application.name.label'),
      default: true,
      render: (client) => <ResourceNameCell id={client.id} name={client.name} />,
    },
    {
      key: 'client_id',
      label: i18n.t('admin.pages.settings.oauth_clients.table.client_id'),
      default: true,
      render: (client) => (
        <span className="flex items-center gap-1">
          <code className="truncate font-mono text-xs">{client.client_id}</code>
          <CopyToClipboardButton
            value={client.client_id}
            aria-label={i18n.t('admin.pages.settings.oauth_clients.copy_client_id')}
          />
        </span>
      ),
    },
    {
      key: 'redirect_uri',
      label: i18n.t('admin.fields.oauth_application.redirect_uri.label'),
      default: true,
      render: (client) => <code className="font-mono text-xs">{client.redirect_uri}</code>,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.pages.settings.oauth_clients.table.created'),
      default: true,
      render: (client) => <RelativeTime iso={client.created_at} />,
    },
  ],
})
