import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const contact = await client.companyLocations.contacts.create('cloc_UkLWZg9DAJ', {
  customer_id: 'cus_UkLWZg9DAJ',
  role: 'buyer',
})

// endregion:example

export { contact }
