import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const products = await client.products.list({
  page: 1,
  limit: 25,
  sort: 'price',
  name_cont: 'shirt',
  price_gte: 20,
  price_lte: 100,
  with_option_value_ids: ['optval_abc', 'optval_def'],
  expand: ['variants', 'media'],
})
// endregion:example

export { products }
