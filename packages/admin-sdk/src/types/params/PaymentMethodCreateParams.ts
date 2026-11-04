// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PaymentMethodCreateParams = {
  /** Wire shorthand from the payment method types endpoint. */
  type: string
  name: string
  description?: string | null
  active?: boolean
  /** False keeps the method to the dashboard; true also offers it on the storefront. */
  storefront_visible?: boolean
  /** When customers are charged for this method. Null inherits the store setting. */
  capture_method?: 'checkout' | 'on_dispatch' | 'manual' | null
  position?: number
  metadata?: Record<string, unknown>
  /** Values for the provider's preference schema, from the payment method types endpoint. */
  preferences?: Record<string, unknown>
  /**
   * Conditions that decide whether the method is offered at storefront checkout. Replaces the full
   * set: omitted rules are removed.
   */
  rules?: {
    id?: string
    /** A rule kind from the payment method rule types endpoint. */
    type?: string
    active?: boolean
    preferences?: Record<string, unknown>
  }[]
}
