import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const optionType = await client.optionTypes.create({
  name: 'color',
  label: 'Color',
  option_values: [
    { name: 'red', label: 'Red' },
    { name: 'navy', label: 'Navy' },
  ],
})

// endregion:example

export { optionType }
