import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
})

// region:example
const me = await client.me.get()

// endregion:example

export { me }
