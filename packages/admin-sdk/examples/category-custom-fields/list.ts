import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: customFields } = await client.categories.customFields.list('ctg_UkLWZg9DAJ')

// endregion:example

export { customFields }
