import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
const { providers } = await client.auth.providers()

// endregion:example

export { providers }
