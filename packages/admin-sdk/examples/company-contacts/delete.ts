import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Withdraws the buyer's authority; the customer account is untouched.
await client.companyContacts.delete('cc_UkLWZg9DAJ')
// endregion:example
