import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Omit `mappings` to accept the columns assigned on create.
const productImport = await client.imports.completeMapping('imp_UkLWZg9DAJ', {
  mappings: [
    { schema_field: 'slug', file_column: 'handle' },
    { schema_field: 'price', file_column: 'price_usd' },
  ],
})

// endregion:example

export { productImport }
