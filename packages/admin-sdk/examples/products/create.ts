import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const product = await client.products.create({
  name: 'Premium T-Shirt',
  // Rich text: send HTML. Reads return this as plain text, plus
  // `description_html` with the markup.
  description: '<p>Soft, organic cotton.</p>',
  status: 'active',
  variants: [
    {
      sku: 'TSHIRT-S-NAVY',
      options: [
        { name: 'size', value: 'Small' },
        { name: 'color', value: 'navy' },
      ],
      prices: [
        { currency: 'USD', amount: '29.99' },
        { currency: 'EUR', amount: '27.99' },
      ],
      stock_items: [{ stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 50 }],
    },
    {
      sku: 'TSHIRT-M-NAVY',
      options: [
        { name: 'size', value: 'Medium' },
        { name: 'color', value: 'navy' },
      ],
      prices: [{ currency: 'USD', amount: '29.99' }],
      stock_items: [{ stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 30 }],
    },
  ],
})

// endregion:example

export { product }
