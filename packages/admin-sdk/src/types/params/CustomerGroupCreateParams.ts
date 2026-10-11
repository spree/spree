// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CustomerGroupCreateParams = {
  name: string
  description?: string | null
  /** Replaces the group's members. */
  customer_ids?: string[]
}
