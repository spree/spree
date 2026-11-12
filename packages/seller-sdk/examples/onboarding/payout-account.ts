import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const link = await client.onboarding.payoutAccount({
  refresh_url: 'https://sellers.your-store.com/onboarding',
  return_url: 'https://sellers.your-store.com/onboarding',
})

// endregion:example

export { link }
