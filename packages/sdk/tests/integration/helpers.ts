import { createClient } from '../../src'
import { getCredentials } from './setup'

export function client() {
  const creds = getCredentials()
  return createClient({
    baseUrl: creds.base_url,
    publishableKey: creds.publishable_key,
  })
}

export function authOpts() {
  return { token: getCredentials().jwt_token }
}

export function testAddress(overrides: Record<string, string> = {}) {
  return {
    first_name: 'Test',
    last_name: 'Checkout',
    address1: '1 Times Square',
    city: 'New York',
    postal_code: '10036',
    country_iso: getCredentials().country_iso,
    state_abbr: 'NY',
    phone: '555-0100',
    ...overrides,
  }
}

/**
 * Build a cart through the checkout to a given step.
 */
export async function buildCart(throughStep: 'item' | 'address' | 'delivery' | 'payment') {
  const creds = getCredentials()
  const c = client()

  const products = await c.products.list()
  const variantId = products.data.find(
    (p) => p.purchasable && p.default_variant_id,
  )!.default_variant_id

  const cart = await c.carts.create()
  const opts = { spreeToken: cart.token }

  await c.carts.items.create(cart.id, { variant_id: variantId, quantity: 1 }, opts)
  if (throughStep === 'item') return { c, cart, opts, creds }

  const withAddr = await c.carts.update(
    cart.id,
    {
      email: `test-${Date.now()}@example.com`,
      shipping_address: testAddress(),
      billing_address: testAddress(),
    },
    opts,
  )
  if (throughStep === 'address') return { c, cart: withAddr, opts, creds }

  const ful = withAddr.fulfillments[0]
  const withRate = await c.carts.fulfillments.update(
    cart.id,
    ful.id,
    {
      selected_delivery_rate_id: ful.delivery_rates[0].id,
    },
    opts,
  )
  if (throughStep === 'delivery') return { c, cart: withRate, opts, creds }

  const session = await c.carts.paymentSessions.create(
    cart.id,
    {
      payment_method_id: creds.bogus_payment_method_id,
    },
    opts,
  )
  return { c, cart: withRate, opts, creds, session }
}
