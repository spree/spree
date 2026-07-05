import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Set the signed-in admin's own UI display language.
const me = await client.me.update({
  selected_locale: 'de',
})

// endregion:example

export { me }
