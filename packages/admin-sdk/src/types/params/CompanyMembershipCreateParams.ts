// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CompanyMembershipCreateParams = {
  /** An existing customer, who becomes a member immediately. Send this or `customer_email`. */
  customer_id?: string
  /**
   * An existing customer becomes a member immediately; an unknown email becomes an invitation, and
   * the response is an invitation instead of a membership. Send this or `customer_id`.
   */
  customer_email?: string
  metadata?: Record<string, unknown>
}
