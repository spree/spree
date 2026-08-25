import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: catalogs } = await client.catalogs.list({ active_eq: true })

// endregion:example

/** Active catalogs in the store. */
export { catalogs }
