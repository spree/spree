import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// What you can ask for, and the configuration each kind takes. A kind your own
// code registers server-side shows up here too.
const { data: requirementTypes } = await client.sellerRequirements.types()

// endregion:example

export { requirementTypes }
