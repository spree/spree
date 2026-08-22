import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const company = await client.companies.create({
  name: 'Globex Corporation',
  external_references: { erp: 'GLBX-42' },
})

// endregion:example

export { company }
