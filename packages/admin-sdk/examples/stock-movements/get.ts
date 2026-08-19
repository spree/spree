import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const stockMovement = await client.stockMovements.get('sm_k5nR8xLq')

// endregion:example

export { stockMovement }
