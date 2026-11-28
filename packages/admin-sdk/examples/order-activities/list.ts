import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const activities = await client.orders.activities.list('or_UkLWZg9DAJ', {
  expand: ['actor', 'order_change.actions.variant'],
})

// endregion:example

export { activities }
