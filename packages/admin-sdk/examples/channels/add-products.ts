import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Idempotent — re-publishing an already-published product updates its
// publication window. `published_at`/`unpublished_at` are optional:
// `null` (or omitted) means live immediately and never come down.
const { product_count } = await client.channels.addProducts('channel_xxx', {
  product_ids: ['prod_xxx', 'prod_yyy'],
  published_at: '2026-07-01T00:00:00Z',
})

// endregion:example

export { product_count }
