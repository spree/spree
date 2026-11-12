import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `catalog_price` adds what a buyer on this agreement pays for each product.
const { data: products } = await client.catalogs.products.list('cat_UkLWZg9DAJ', {
  expand: ['catalog_price'],
})

// endregion:example

export { products }
