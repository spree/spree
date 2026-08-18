import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Also the way back for a seller that was suspended or turned down — and it
// clears any holiday along with the suspension.
const seller = await client.sellers.approve('sel_UkLWZg9DAJ')

// endregion:example

export { seller }
