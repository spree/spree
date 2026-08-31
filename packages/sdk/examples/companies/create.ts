import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const company = await client.companies.create(
  {
    name: 'Nowak Tools sp. z o.o.',
    registration: { vat_number: 'PL1234567890', employees: '50' },
  },
  { token: '<token>' },
)

// endregion:example

export { company }
