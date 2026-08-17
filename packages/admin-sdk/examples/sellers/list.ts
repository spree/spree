import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `sellable` is the one to read for "can this seller be bought from" — an
// approved seller who is away answers false.
const { data: sellers } = await client.sellers.list({ page: 1, limit: 25 })

// endregion:example

export { sellers }
