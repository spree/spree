import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// An automatic collection: its products are the ones matching the rules.
const collection = await client.collections.create({
  name: 'On Sale',
  automatic: true,
  rules_match_policy: 'any',
  rules: [{ type: 'tag', value: 'summer', match_policy: 'contains' }],
})

// endregion:example

export { collection }
