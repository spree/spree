import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const variant = await client.products.variants.create('prod_86Rf07xd4z', {
  sku: 'TSHIRT-L-NAVY',
  options: [
    { name: 'size', value: 'Large' },
    { name: 'color', value: 'navy' },
  ],
  prices: [
    { currency: 'USD', amount: '29.99', compare_at_amount: '34.99' },
    { currency: 'EUR', amount: '27.99' },
  ],
  stock_items: [{ stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 25 }],
})

// endregion:example

export { variant }
