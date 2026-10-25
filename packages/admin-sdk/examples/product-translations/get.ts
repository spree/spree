import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Source values and every locale's translations, including the product's variants and options.
const translations = await client.products.translations.get('prod_UkLWZg9DAJ')

// endregion:example

export { translations }
