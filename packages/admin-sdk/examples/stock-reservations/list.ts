import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Stock held for checkouts in progress, soonest to expire first.
const { data: reservations } = await client.stockReservations.list({
  sort: 'expires_at',
})

// endregion:example

export { reservations }
