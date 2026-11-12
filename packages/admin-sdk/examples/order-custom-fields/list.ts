import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: customFields } = await client.orders.customFields.list('or_UkLWZg9DAJ')

// endregion:example

export { customFields }
