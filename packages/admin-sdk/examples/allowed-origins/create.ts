import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const origin = await client.allowedOrigins.create({
  origin: 'https://admin.example.com',
})
// endregion:example

export { origin }
