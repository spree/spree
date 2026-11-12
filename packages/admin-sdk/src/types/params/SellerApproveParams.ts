// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SellerApproveParams = {
  /**
   * Admits a seller whose onboarding checklist is unfinished: the operator's deliberate exception,
   * which the `seller.approved` event records along with what was outstanding.
   */
  override_requirements?: boolean
}
