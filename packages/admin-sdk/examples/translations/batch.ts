import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// All entries are saved together, or none are.
const translations = await client.translations.batch([
  {
    resource_type: 'option_type',
    resource_id: 'opt_UkLWZg9DAJ',
    values: { de: { label: 'Größe' } },
  },
  {
    resource_type: 'option_value',
    resource_id: 'optval_UkLWZg9DAJ',
    values: { de: { label: 'Klein' } },
  },
])

// endregion:example

export { translations }
