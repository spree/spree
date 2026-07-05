import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Single coupon code, no rules/actions
const promotion = await client.promotions.create({
  name: 'Black Friday',
  code: 'BLACKFRIDAY',
  starts_at: '2026-11-29T00:00:00Z',
  expires_at: '2026-12-01T00:00:00Z',
})

// One-shot: promotion + rules + actions in a single request
const blackFriday = await client.promotions.create({
  name: 'Black Friday',
  code: 'BLACKFRIDAY',
  kind: 'coupon_code',
  starts_at: '2026-11-29T00:00:00Z',
  expires_at: '2026-12-01T00:00:00Z',
  match_policy: 'all',
  rules: [
    {
      type: 'currency',
      preferences: { currency: 'USD' },
    },
    {
      type: 'item_total',
      preferences: { amount_min: 100, operator_min: 'gte' },
    },
    {
      type: 'product',
      preferences: { match_policy: 'any' },
      product_ids: ['prod_abc123', 'prod_def456'],
    },
  ],
  actions: [
    {
      type: 'create_item_adjustments',
      calculator: {
        type: 'percent_on_line_item',
        preferences: { percent: 25 },
      },
    },
    { type: 'free_shipping' },
  ],
})
// endregion:example

// Suppress unused-binding warnings — these are display-only example values.
export { promotion, blackFriday }
