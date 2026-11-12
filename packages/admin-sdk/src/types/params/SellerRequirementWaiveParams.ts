// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SellerRequirementWaiveParams = {
  /** The requirement the seller is excused from. */
  requirement_id: string
  /** Why the seller is excused. Kept with the decision. */
  review_note?: string
}
