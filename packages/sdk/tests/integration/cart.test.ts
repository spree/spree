import { describe, expect, it } from 'vitest'
import { buildCart, client } from './helpers'

describe('cart items', () => {
  it('creates a cart, adds item, updates, removes', async () => {
    const c = client()

    const products = await c.products.list()
    const variantId = products.data.find(
      (p) => p.purchasable && p.default_variant_id,
    )!.default_variant_id

    const cart = await c.carts.create()
    expect(cart.id).toMatch(/^cart_/)
    expect(cart.token).toBeDefined()
    expect(cart).toHaveProperty('items')
    expect(cart).toHaveProperty('fulfillments')
    expect(cart).toHaveProperty('payment_methods')
    expect(cart).toHaveProperty('payments')

    const opts = { spreeToken: cart.token }

    const updated = await c.carts.items.create(
      cart.id,
      { variant_id: variantId, quantity: 2 },
      opts,
    )
    expect(updated.items.length).toBe(1)
    expect(updated.items[0].quantity).toBe(2)

    const lineItemId = updated.items[0].id
    const after = await c.carts.items.update(cart.id, lineItemId, { quantity: 1 }, opts)
    expect(after.items[0].quantity).toBe(1)

    const empty = await c.carts.items.delete(cart.id, lineItemId, opts)
    expect(empty.items.length).toBe(0)
  })
})

describe('cart addresses', () => {
  it('sets shipping and billing addresses', async () => {
    const { cart } = await buildCart('address')

    expect(cart.shipping_address).toBeDefined()
    expect(cart.billing_address).toBeDefined()
    expect(cart.email).toBeDefined()
  })
})

describe('cart fulfillments', () => {
  it('selects a delivery rate', async () => {
    const { cart } = await buildCart('delivery')

    expect(Number(cart.delivery_total)).toBeGreaterThan(0)
  })
})

describe('cart payment sessions', () => {
  it('creates and gets a payment session', async () => {
    const { c, cart, opts, creds } = await buildCart('delivery')

    const session = await c.carts.paymentSessions.create(
      cart.id,
      {
        payment_method_id: creds.bogus_payment_method_id,
      },
      opts,
    )

    expect(session.id).toMatch(/^ps_/)
    expect(session.status).toBe('pending')
    expect(session.payment_method_id).toBe(creds.bogus_payment_method_id)

    const fetched = await c.carts.paymentSessions.get(cart.id, session.id, opts)
    expect(fetched.id).toBe(session.id)
  })

  it('completes a payment session', async () => {
    const { c, cart, opts, session } = await buildCart('payment')

    const completed = await c.carts.paymentSessions.complete(cart.id, session!.id, undefined, opts)
    expect(completed.status).toBe('completed')
  })
})

describe('cart completion', () => {
  it('completes cart with Check payment and returns order', async () => {
    const { c, cart, opts, creds } = await buildCart('delivery')

    const payment = await c.carts.payments.create(
      cart.id,
      {
        payment_method_id: creds.check_payment_method_id,
      },
      opts,
    )
    expect(payment.id).toMatch(/^py_/)

    const order = await c.carts.complete(cart.id, opts)

    expect(order.id).toMatch(/^or_/)
    expect(order.number).toBeDefined()
    expect(order.completed_at).toBeDefined()
    expect(order.payment_status).toBeDefined()
    expect(order.items.length).toBeGreaterThan(0)
  })

  it('gets a completed order as guest via spree token', async () => {
    const { c, cart, opts, creds } = await buildCart('delivery')
    await c.carts.payments.create(
      cart.id,
      { payment_method_id: creds.check_payment_method_id },
      opts,
    )
    const order = await c.carts.complete(cart.id, opts)

    const fetched = await c.orders.get(order.id, undefined, opts)

    expect(fetched.id).toBe(order.id)
    expect(fetched.number).toBe(order.number)
    expect(fetched.completed_at).toBeDefined()
  })
})
