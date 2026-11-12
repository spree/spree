import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
const invitation = await client.auth.lookupInvitation('inv_xxx', 'token-from-email')

// endregion:example

export { invitation }
