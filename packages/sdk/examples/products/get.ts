import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const product = await client.products.get('spree-tote', {
  expand: ['variants', 'media', 'variants.volume_prices'],
})

const tiers = product.variants?.[0]?.volume_prices ?? []

// endregion:example

export { product, tiers }
