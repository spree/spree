import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `code` is optional — when omitted it's derived from `name`
// ("Point of Sale" → "point-of-sale").
const channel = await client.channels.create({
  name: 'Point of Sale',
  code: 'pos',
  active: true,
})

// endregion:example

export { channel }
