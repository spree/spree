import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const invoiceRequest = await client.orders.invoiceRequests.create(
  'or_abc123',
  { company_name: 'Acme GmbH', tax_id: 'DE123456789' },
  { token: '<token>' },
)

// endregion:example

export { invoiceRequest }
