import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: events } = await client.storeCredits.events.list('credit_abc123')

// endregion:example

export { events }
