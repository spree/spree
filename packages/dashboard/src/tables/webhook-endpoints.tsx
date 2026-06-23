import type { WebhookEndpoint } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import {
  ActiveBadge,
  Badge,
  CopyToClipboardButton,
  RelativeTime,
  ResourceNameCell,
} from '@spree/dashboard-ui'
import i18n from 'i18next'
import { WebhookIcon } from 'lucide-react'
import { webhookEndpointHealth, webhookHealthBadgeVariant } from '@/lib/webhook-health'

defineTable<WebhookEndpoint>('webhook-endpoints', {
  title: i18n.t('admin.pages.settings.webhooks.title'),
  searchParam: 'url_cont',
  searchPlaceholder: i18n.t('admin.pages.settings.webhooks.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <WebhookIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.pages.settings.webhooks.empty_title'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (endpoint) => (
        <ResourceNameCell
          id={endpoint.id}
          dataAttr="data-webhook-endpoint-id"
          name={endpoint.name || endpoint.url}
        />
      ),
    },
    {
      key: 'url',
      label: i18n.t('admin.pages.settings.webhooks.table.url'),
      sortable: true,
      filterable: true,
      default: true,
      render: (endpoint) => (
        <span className="inline-flex items-center gap-1.5">
          <span className="font-mono text-xs text-muted-foreground truncate max-w-md inline-block">
            {endpoint.url}
          </span>
          <CopyToClipboardButton
            value={endpoint.url}
            aria-label={i18n.t('admin.pages.settings.webhooks.table.copy_url_aria')}
          />
        </span>
      ),
    },
    {
      key: 'subscriptions',
      label: i18n.t('admin.pages.settings.webhooks.table.events'),
      sortable: false,
      default: true,
      render: (endpoint) => {
        if (!endpoint.subscriptions || endpoint.subscriptions.length === 0) {
          return (
            <Badge variant="secondary">{i18n.t('admin.pages.settings.webhooks.events_all')}</Badge>
          )
        }
        return (
          <span className="text-sm text-muted-foreground">
            {i18n.t('admin.pages.settings.webhooks.events_count', {
              count: endpoint.subscriptions.length,
            })}
          </span>
        )
      },
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: false,
      default: true,
      render: (endpoint) => {
        // Auto-disabled is a distinct third state (the SSRF / failure
        // threshold tripped) — surface it with the destructive variant rather
        // than the regular inactive outline so admins can spot it at a glance.
        if (endpoint.disabled_at) {
          return (
            <Badge variant="destructive">
              {i18n.t('admin.pages.settings.webhooks.status.disabled')}
            </Badge>
          )
        }
        return (
          <ActiveBadge
            active={endpoint.active}
            activeLabel={i18n.t('admin.fields.active.label')}
            inactiveLabel={i18n.t('admin.pages.settings.webhooks.status.inactive')}
          />
        )
      },
    },
    {
      key: 'health',
      label: i18n.t('admin.pages.settings.webhooks.health.label'),
      sortable: false,
      default: true,
      render: (endpoint) => {
        const bucket = webhookEndpointHealth(endpoint)
        const variant = webhookHealthBadgeVariant(bucket)

        let label: string
        switch (bucket.kind) {
          case 'disabled':
            label = i18n.t('admin.pages.settings.webhooks.health.disabled')
            break
          case 'no_deliveries':
            label = i18n.t('admin.pages.settings.webhooks.health.no_deliveries')
            break
          case 'healthy':
            label = i18n.t('admin.pages.settings.webhooks.health.healthy', {
              percentage: bucket.percentage,
            })
            break
          case 'degraded':
            label = i18n.t('admin.pages.settings.webhooks.health.degraded', {
              percentage: bucket.percentage,
            })
            break
          case 'failing':
            label = i18n.t('admin.pages.settings.webhooks.health.failing', {
              percentage: bucket.percentage,
            })
            break
        }

        const total = endpoint.total_delivery_count ?? 0
        const successful = endpoint.successful_delivery_count ?? 0
        const failed = endpoint.failed_delivery_count ?? 0

        return (
          <div className="flex flex-col gap-1">
            <Badge variant={variant} className="self-start">
              {label}
            </Badge>
            {total > 0 && (
              <span className="text-xs text-muted-foreground">
                {i18n.t('admin.pages.settings.webhooks.health.row_counters_successful', {
                  count: successful,
                })}
                {' · '}
                {i18n.t('admin.pages.settings.webhooks.health.row_counters_failed', {
                  count: failed,
                })}
              </span>
            )}
          </div>
        )
      },
    },
    {
      key: 'last_delivery_at',
      label: i18n.t('admin.pages.settings.webhooks.table.last_delivery'),
      sortable: false,
      default: true,
      render: (endpoint) =>
        endpoint.last_delivery_at ? (
          <RelativeTime iso={endpoint.last_delivery_at} />
        ) : (
          <span className="text-sm text-muted-foreground">—</span>
        ),
    },
  ],
})
