import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const company = await client.companies.update('comp_UkLWZg9DAJ', {
  name: 'Acme Industrial Group',
  po_number_required: true,
})

// endregion:example

export { company }
