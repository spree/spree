// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type RequestNewsletterUnsubscribeParams = {
  email?: string
  /**
   * The storefront URL the unsubscribe token is appended to in the email. Left out of the event
   * payload unless it matches one of the store's allowed origins.
   */
  redirect_url?: string
}
