import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const productImport = await client.imports.retryFailedRows('imp_UkLWZg9DAJ')

// endregion:example

export { productImport }
