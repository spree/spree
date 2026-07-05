import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// One-shot order create: customer, items, addresses, market, channel,
// notes, metadata, and a coupon code in a single call. Everything
// except `email` is optional.
const order = await client.orders.create({
  email: 'jane@example.com',
  customer_id: 'cus_UkLWZg9DAJ',           // Existing customer; omit for guest orders
  use_customer_default_address: false,     // true to copy the customer's saved addresses

  currency: 'USD',
  market_id: 'mkt_UkLWZg9DAJ',
  channel_id: 'ch_UkLWZg9DAJ',             // Optional — defaults to the store's primary channel
  locale: 'en-US',

  // Pin the order's preferred fulfillment location. Order Routing's
  // built-in PreferredLocation rule ranks this location first when
  // it stocks the cart's items; if it doesn't, routing falls back
  // to the next rule (Minimize Splits → Default Location).
  preferred_stock_location_id: 'sloc_UkLWZg9DAJ',

  customer_note: 'Please leave at the front desk.',
  internal_note: 'VIP customer — handle with care.',
  metadata: {
    external_reference: 'subscription_invoice_2026_04',
    source: 'recurring-engine',
  },

  // Items: each variant_id + quantity. Optional metadata per line.
  items: [
    { variant_id: 'variant_k5nR8xLq', quantity: 2 },
    { variant_id: 'variant_QXyZ12abCD', quantity: 1, metadata: { gift: true } },
  ],

  // Provide addresses inline OR by ID (existing customer addresses).
  shipping_address: {
    first_name: 'Jane',
    last_name: 'Doe',
    address1: '350 Fifth Avenue',
    address2: 'Floor 42',
    city: 'New York',
    postal_code: '10118',
    country_iso: 'US',
    state_abbr: 'NY',
    phone: '+1 212 555 1234',
    company: 'Acme Inc.',
  },
  // shipping_address_id: 'addr_UkLWZg9DAJ',  // alternative to inline

  billing_address: {
    first_name: 'Jane',
    last_name: 'Doe',
    address1: '350 Fifth Avenue',
    city: 'New York',
    postal_code: '10118',
    country_iso: 'US',
    state_abbr: 'NY',
    phone: '+1 212 555 1234',
  },
  // billing_address_id: 'addr_UkLWZg9DAJ',

  // Optional. Invalid codes are non-fatal — the order is created either way.
  coupon_code: 'WELCOME10',
})
// endregion:example

export { order }
