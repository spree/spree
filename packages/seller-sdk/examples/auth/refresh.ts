import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
const auth = await client.auth.refresh()

// endregion:example

export { auth }
