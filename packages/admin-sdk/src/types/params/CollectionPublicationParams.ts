// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CollectionPublicationParams = {
  channel_id?: string
  /** When the collection goes live on the channel. Null means immediately. */
  published_at?: string | null
  /** When the collection comes down from the channel. Null means never. */
  unpublished_at?: string | null
}
