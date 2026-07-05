import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const optionType = await client.optionTypes.update('ot_UkLWZg9DAJ', {
  label: 'Updated Label',
  option_values: [{ name: 'red', label: 'Crimson' }],
})

// endregion:example

export { optionType }
