// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ChannelCreateParams = {
  name: string
  /** URL-safe slug, derived from `name` when blank (`Point of Sale` becomes `point-of-sale`). */
  code?: string
  active?: boolean
  default?: boolean
  /** Order routing strategy shorthand (built-in: `rules`). Null inherits the store setting. */
  order_routing_strategy?: string | null
  /** What anonymous visitors can see. Null inherits the store setting. */
  storefront_access?: 'public' | 'prices_hidden' | 'login_required' | null
  /** Whether guests can check out without an account. Null inherits the store setting. */
  guest_checkout?: boolean | null
  /**
   * Catalog (`cat_...`) shown to shoppers no company or customer group catalog covers. Null means
   * every product published on the channel.
   */
  default_catalog_id?: string | null
  /**
   * Stock locations (`sloc_...`) that fulfill this channel. Replaces the whole set; an empty list
   * means every location of the store.
   */
  stock_location_ids?: string[]
}
