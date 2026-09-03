import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
await client.wishlists.items.delete('wl_abc123', 'wli_abc123', {
  token: '<token>',
})
// endregion:example
