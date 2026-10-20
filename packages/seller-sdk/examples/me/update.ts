import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
})

// region:example
const me = await client.me.update({
  first_name: 'Jane',
  last_name: 'Doe',
  selected_locale: 'en',
})

// endregion:example

export { me }
