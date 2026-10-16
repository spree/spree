// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type WebhookEndpointUpdateParams = {
  /** A label shown in the dashboard list. */
  name?: string | null
  /** HTTPS destination URL. It cannot resolve to a private IP address outside development. */
  url?: string
  /** Defaults to true on create. Prefer the disable and enable endpoints to pause one. */
  active?: boolean
  /**
   * Event names this endpoint receives. An empty list or `["*"]` subscribes to every event;
   * otherwise list exact names (`order.completed`) or patterns (`order.*`).
   */
  subscriptions?: string[]
}
