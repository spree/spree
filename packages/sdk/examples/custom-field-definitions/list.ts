import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// The fields to ask for at checkout, with their type, label and rules.
const checkoutFields = await client.customFieldDefinitions.list({
  resource_type_eq: 'order',
})

// endregion:example

export { checkoutFields }
