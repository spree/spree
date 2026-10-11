// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type OnboardingPayoutAccountParams = {
  /**
   * Where the provider sends the seller back. Must be on the seller panel's origin; any other
   * address is replaced with the panel's.
   */
  refresh_url: string
  /**
   * Where the provider sends the seller back. Must be on the seller panel's origin; any other
   * address is replaced with the panel's.
   */
  return_url: string
}
