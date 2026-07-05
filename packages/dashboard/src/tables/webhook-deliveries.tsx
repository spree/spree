import type { WebhookDelivery } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ListIcon } from 'lucide-react'

// `success` on a delivery is tri-state: `true` (HTTP 2xx received), `false`
// (response/transport error), or `null` (queued, not yet attempted). The
// table filter exposes the two non-pending values so admins can quickly
// triage failures.
const STATUS_OPTIONS = [
  { value: 'true', label: i18n.t('admin.pages.settings.webhooks.deliveries.status.success') },
  { value: 'false', label: i18n.t('admin.pages.settings.webhooks.deliveries.status.failure') },
] as const

defineTable<WebhookDelivery>('webhook-deliveries', {
  title: i18n.t('admin.pages.settings.webhooks.deliveries_sheet_title'),
  searchParam: 'event_name_cont',
  searchPlaceholder: i18n.t('admin.pages.settings.webhooks.deliveries.search_placeholder'),
  // `created_at` (not `delivered_at`) so freshly-queued rows whose
  // `delivered_at` is still null sort to the top. Matches the model's
  // `recent` scope and what an admin opening this dialog expects to see
  // (most recent attempt first, including not-yet-attempted ones).
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <ListIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.pages.settings.webhooks.deliveries.empty'),
  columns: [
    {
      key: 'event_name',
      label: i18n.t('admin.pages.settings.webhooks.deliveries.table.event'),
      sortable: true,
      filterable: true,
      default: true,
      render: (delivery) => (
        <button
          type="button"
          // Acts as the row-click target. The detail sheet opens via the
          // parent's `useRowClickBridge('data-webhook-delivery-id', …)`.
          data-webhook-delivery-id={delivery.id}
          className="font-mono text-xs underline-offset-2 hover:underline focus-visible:rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {delivery.event_name}
        </button>
      ),
    },
    {
      key: 'success',
      label: i18n.t('admin.fields.status.label'),
      sortable: false,
      filterable: true,
      filterType: 'enum',
      filterOptions: [...STATUS_OPTIONS],
      default: true,
      render: (delivery) => {
        if (delivery.delivered_at == null) {
          return (
            <Badge variant="secondary">
              {i18n.t('admin.pages.settings.webhooks.deliveries.status.pending')}
            </Badge>
          )
        }
        if (delivery.success === true) {
          return <Badge>{i18n.t('admin.pages.settings.webhooks.deliveries.status.success')}</Badge>
        }
        if (delivery.error_type) {
          return (
            <Badge variant="destructive">
              {i18n.t('admin.pages.settings.webhooks.deliveries.status.error')}
            </Badge>
          )
        }
        return (
          <Badge variant="destructive">
            {i18n.t('admin.pages.settings.webhooks.deliveries.status.failure')}
          </Badge>
        )
      },
    },
    {
      key: 'response_code',
      label: i18n.t('admin.pages.settings.webhooks.deliveries.table.code'),
      sortable: true,
      filterable: true,
      filterType: 'number',
      default: true,
      render: (delivery) => {
        if (delivery.response_code != null) {
          return <code className="font-mono text-xs">{delivery.response_code}</code>
        }
        if (delivery.error_type) {
          return <span className="text-xs text-muted-foreground">{delivery.error_type}</span>
        }
        return <span className="text-xs text-muted-foreground">—</span>
      },
    },
    {
      key: 'execution_time',
      label: i18n.t('admin.pages.settings.webhooks.deliveries.table.execution_time'),
      sortable: true,
      default: true,
      render: (delivery) =>
        delivery.execution_time != null ? (
          <span className="text-xs text-muted-foreground">{delivery.execution_time}ms</span>
        ) : (
          <span className="text-xs text-muted-foreground">—</span>
        ),
    },
    {
      key: 'delivered_at',
      label: i18n.t('admin.pages.settings.webhooks.deliveries.table.delivered_at'),
      sortable: true,
      default: true,
      render: (delivery) =>
        delivery.delivered_at ? (
          <RelativeTime iso={delivery.delivered_at} />
        ) : (
          <span className="text-xs text-muted-foreground">—</span>
        ),
    },
  ],
})
