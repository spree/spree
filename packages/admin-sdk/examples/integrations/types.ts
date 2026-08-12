import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: integrationTypes } = await client.integrations.types()

// endregion:example

export { integrationTypes }
