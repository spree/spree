import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: optionTypes } = await client.optionTypes.list()
// endregion:example

export { optionTypes }
