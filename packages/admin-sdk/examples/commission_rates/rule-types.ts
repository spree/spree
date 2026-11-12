import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Each kind comes with the JSON Schema of its configuration.
const { data: ruleTypes } = await client.commissionRates.ruleTypes()

// endregion:example

export { ruleTypes }
