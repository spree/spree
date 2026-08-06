import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const integration = await client.integrations.create({
  type: 'carrier',
  preferences: { api_key: 'sk-secret', account_number: '42' },
})

// endregion:example

export { integration }
