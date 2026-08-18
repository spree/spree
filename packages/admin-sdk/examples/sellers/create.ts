import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The seller starts as `pending` and has no team yet — invite someone to run
// it next.
const seller = await client.sellers.create({
  name: 'Northwind Books',
  contact_email: 'hi@northwind.example',
})

// endregion:example

export { seller }
