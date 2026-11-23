import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const optionType = await client.optionTypes.get('opt_UkLWZg9DAJ', {
  expand: ['option_values'],
})

// endregion:example

export { optionType }
