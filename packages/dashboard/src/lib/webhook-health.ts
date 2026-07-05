import type { WebhookEndpoint } from '@spree/admin-sdk'

export type WebhookHealthBucket =
  | { kind: 'disabled' }
  | { kind: 'no_deliveries' }
  | { kind: 'healthy' | 'degraded' | 'failing'; percentage: number }

/**
 * Mirrors `webhook_endpoint_health_badge` from
 * `spree/admin/app/helpers/spree/admin/webhook_endpoints_helper.rb` so the SPA
 * and the legacy admin agree on what counts as healthy/degraded/failing.
 *
 * Thresholds: ≥95% success → healthy, ≥80% → degraded, otherwise failing.
 */
export function webhookEndpointHealth(endpoint: WebhookEndpoint): WebhookHealthBucket {
  if (endpoint.disabled_at) return { kind: 'disabled' }

  const total = endpoint.total_delivery_count ?? 0
  if (total === 0) return { kind: 'no_deliveries' }

  const successful = endpoint.successful_delivery_count ?? 0
  const percentage = Math.round((successful / total) * 10000) / 100

  if (percentage >= 95) return { kind: 'healthy', percentage }
  if (percentage >= 80) return { kind: 'degraded', percentage }
  return { kind: 'failing', percentage }
}

export function webhookHealthBadgeVariant(
  bucket: WebhookHealthBucket,
): 'default' | 'secondary' | 'destructive' {
  switch (bucket.kind) {
    case 'healthy':
      return 'default'
    case 'degraded':
    case 'no_deliveries':
      return 'secondary'
    case 'failing':
    case 'disabled':
      return 'destructive'
  }
}
