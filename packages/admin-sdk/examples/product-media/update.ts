import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const media = await client.products.media.update('prod_UkLWZg9DAJ', 'media_gbHJdmfrXB', {
  alt: 'Side view',
  position: 1,
  variant_ids: ['variant_UkLWZg9DAJ'],
})

// endregion:example

export { media }
