// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ApiKeyCreateParams = {
  name: string
  key_type: 'publishable' | 'secret'
  /**
   * Required for secret keys. You can only grant scopes you hold yourself. Fixed once created: to
   * change them, create a new key and revoke the old one.
   */
  scopes?: string[]
  /**
   * Binds a publishable key to one channel of the store (`ch_...`), so it rejects requests for
   * other channels. Fixed once created; omit it for a store-wide key.
   */
  channel_id?: string
}
