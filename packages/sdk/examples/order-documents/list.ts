import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const { data: documents } = await client.orders.documents.list('or_abc123', {}, {
  token: '<token>',
})

// endregion:example

export { documents }
