// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ChannelAddProductsParams = {
  product_ids: string[]
  /** When the publications go live. Null means immediately. */
  published_at?: string | null
  /** When the publications come down. Null means never. */
  unpublished_at?: string | null
}
