import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
await client.auth.requestPasswordReset({
  email: 'seller@example.com',
  redirect_url: 'https://sellers.your-store.com/reset-password',
})
