import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const paymentMethod = await client.paymentMethods.update('pm_UkLWZg9DAJ', {
  name: 'Cheque',
  storefront_visible: false,
  position: 2,
})

// endregion:example

export { paymentMethod }
