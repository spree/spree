import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: failedRows } = await client.imports.rows.list('imp_UkLWZg9DAJ', {
  status_eq: 'failed',
})

// endregion:example

export { failedRows }
