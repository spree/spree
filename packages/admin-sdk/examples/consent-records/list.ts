import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: consentRecords } = await client.consentRecords.list({
  email_eq: 'jane@example.com',
  sort: '-recorded_at',
})

// endregion:example

export { consentRecords }
