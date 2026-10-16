// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreateNewsletterSubscriberParams = {
  email: string
  /**
   * The storefront URL the verification token is appended to. Left out of the webhook payload
   * unless it matches one of the store's allowed origins.
   */
  redirect_url?: string
}
