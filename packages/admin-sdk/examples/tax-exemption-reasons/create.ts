import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `code` is what certificates record and the tax engine receives — on
// Avalara, an entity use code such as `G` (resale).
const reason = await client.taxExemptionReasons.create({
  name: 'Reseller (wholesale)',
  code: 'G',
})

// endregion:example

export { reason }
