import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Server-to-server one-shot create. Ship the rules that gate the list
// and the exact per-variant prices in a single request — variants in
// `prices` implicitly become part of the list (upserted on the unique
// key `(variant_id, currency, price_list_id)`), so there's no need to
// pre-declare `product_ids` separately.
const priceList = await client.priceLists.create({
  name: 'EU wholesale',
  description: 'Tiered pricing for verified B2B customers',
  match_policy: 'all',
  starts_at: '2026-06-01T00:00:00Z',
  ends_at: '2026-09-01T00:00:00Z',
  rules: [
    {
      type: 'customer_group_rule',
      preferences: { customer_group_ids: ['cg_aBc123'] },
    },
    {
      type: 'volume_rule',
      preferences: { min_quantity: 10 },
    },
  ],
  prices: [
    {
      variant_id: 'variant_xY9',
      currency: 'USD',
      amount: '19.99',
      compare_at_amount: '24.99',
    },
    {
      variant_id: 'variant_aB7',
      currency: 'USD',
      amount: '21.99',
    },
  ],
})
// endregion:example

export { priceList }
