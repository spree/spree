import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: definitions } = await client.customFieldDefinitions.list({
  q: { resource_type_eq: 'Spree::Product' },
})
// endregion:example

export { definitions }
