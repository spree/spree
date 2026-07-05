import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

const promotionId = 'promo_UkLWZg9DAJ'

// region:example
// Basic field update
await client.promotions.update(promotionId, {
  description: 'Updated description',
})

// One-shot: rewrite rules + actions in a single request
await client.promotions.update(promotionId, {
  name: 'Holiday Sale',
  rules: [
    // Update an existing rule by id — `preferences` overwrite the prior set
    {
      id: 'prorule_existing',
      type: 'currency',
      preferences: { currency: 'EUR' },
    },
    // Add a new rule
    {
      type: 'item_total',
      preferences: { amount_min: 50, operator_min: 'gte' },
    },
  ],
  actions: [
    // Swap calculator type on an existing action
    {
      id: 'proaction_existing',
      type: 'create_item_adjustments',
      calculator: {
        type: 'percent_on_line_item',
        preferences: { percent: 15 },
      },
    },
  ],
})

// Remove all rules/actions
await client.promotions.update(promotionId, {
  rules: [],
  actions: [],
})
// endregion:example
