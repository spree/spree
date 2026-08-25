import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// The buyer's memberships, each carrying its node and the path above it.
const { data: memberships } = await client.account.companies({ token: '<token>' })

// endregion:example

export { memberships }
