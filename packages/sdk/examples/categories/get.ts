import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const category = await client.categories.get('categories/clothing/shirts', {
  expand: ['children'],
})
// endregion:example

export { category }
