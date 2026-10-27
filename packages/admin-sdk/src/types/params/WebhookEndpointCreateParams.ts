// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type WebhookEndpointCreateParams = {
  /** A label shown in the dashboard list. */
  name?: string | null
  /**
   * HTTPS URL at a host that exists. Outside development it cannot name an internal host or point
   * to a private address, unless the host is in `SPREE_WEBHOOKS_ALLOWED_INTERNAL_HOSTS`. Redirects
   * are not followed.
   */
  url: string
  /** Defaults to true on create. Prefer the disable and enable endpoints to pause one. */
  active?: boolean
  /**
   * Event names this endpoint receives. An empty list or `["*"]` subscribes to every event;
   * otherwise list exact names (`order.completed`) or patterns with `*` in place of a segment
   * (`order.*`, `*.created`). At most 200 entries of up to 100 characters.
   */
  subscriptions?: string[]
}
