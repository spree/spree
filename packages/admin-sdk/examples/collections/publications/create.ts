import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Live on the channel from the given date; omit published_at to go live now.
const publication = await client.collections.publications.create('coll_UkLWZg9DAJ', {
  channel_id: 'ch_UkLWZg9DAJ',
  published_at: '2026-12-01T08:00:00Z',
})

// endregion:example

export { publication }
