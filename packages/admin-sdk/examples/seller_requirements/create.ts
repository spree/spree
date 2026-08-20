import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Asks every seller for a business registration before they can be approved.
// The wording is yours — `document` is one of the open-ended kinds, so a store
// can add as many as it needs, each with its own instructions.
const sellerRequirement = await client.sellerRequirements.create({
  type: 'document',
  name: 'Business registration',
  description: 'A copy of your certificate of incorporation.',
  required: true,
  preferences: { accepted_content_types: ['application/pdf'] },
})

// endregion:example

export { sellerRequirement }
