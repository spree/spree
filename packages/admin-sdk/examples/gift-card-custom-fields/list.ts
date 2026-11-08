import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: customFields } = await client.customFields('gift_card', 'gc_UkLWZg9DAJ').list()

// endregion:example

export { customFields }
