import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `amount` is the fee and `tax_amount` is the VAT charged on that fee — two
// separate supplies, which is why they are not folded together.
const { data: commissionLines } = await client.commissionLines.list({ page: 1, limit: 25 })

// endregion:example

export { commissionLines }
