// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PolicyUpdateParams = {
  /**
   * When the marketplace requires a named policy, use that exact name: the onboarding check matches
   * on it.
   */
  name?: string
  slug?: string
  /**
   * HTML, sanitized before it is stored. `body_html` on the response is the rendering of what was
   * stored.
   */
  body?: string | null
}
