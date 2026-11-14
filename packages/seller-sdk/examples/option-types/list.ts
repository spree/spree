import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: optionTypes } = await client.optionTypes.list({
  expand: ['option_values'],
  sort: 'position',
})

// endregion:example

export { optionTypes }
