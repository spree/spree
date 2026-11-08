/**
 * The shapes a webhook endpoint subscription may take: `*`, an event name
 * (`order.placed`), or a name with `*` in place of whole segments (`order.*`,
 * `*.created`). The server stores nothing else, so a pattern never carries
 * regexp syntax. Mirrors `Spree::WebhookEndpoint.event_pattern?`.
 */
export const WEBHOOK_EVENT_PATTERN = /^(\*|[a-zA-Z0-9_-]+)(\.(\*|[a-zA-Z0-9_-]+))*$/

/** The longest subscription entry an endpoint accepts. */
export const WEBHOOK_SUBSCRIPTION_MAX_LENGTH = 100

/** The most subscription entries one endpoint accepts. */
export const WEBHOOK_SUBSCRIPTIONS_MAX = 200

/** Whether a value is an event name or pattern a webhook endpoint accepts. */
export function isWebhookEventPattern(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length <= WEBHOOK_SUBSCRIPTION_MAX_LENGTH &&
    WEBHOOK_EVENT_PATTERN.test(value)
  )
}
