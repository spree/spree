import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: ruleTypes } = await client.promotionRules.types()
// endregion:example

export { ruleTypes }
