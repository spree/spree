import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const product = await client.products.get('spree-tote', {
  expand: ['variants', 'media'],
})
// endregion:example

export { product }
