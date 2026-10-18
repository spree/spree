import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `price_list_price` adds the price this list sets for each product.
const { data: products } = await client.priceLists.products.list('pl_UkLWZg9DAJ', {
  expand: ['price_list_price'],
})

// endregion:example

export { products }
