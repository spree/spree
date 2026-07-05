import { describe, expect, it } from 'vitest'
import { authOpts, client } from './helpers'
import { getCredentials } from './setup'

describe('customer profile', () => {
  it('gets current customer profile', async () => {
    const customer = await client().customer.get(authOpts())

    expect(customer.email).toBe(getCredentials().user_email)
    expect(customer).toHaveProperty('first_name')
    expect(customer).toHaveProperty('last_name')
  })
})

describe('customer addresses', () => {
  it('creates an address and lists with is_default fields', async () => {
    await client().customer.addresses.create(
      {
        first_name: 'List',
        last_name: 'Test',
        address1: '50 Wall St',
        city: 'New York',
        postal_code: '10005',
        country_iso: 'US',
        state_abbr: 'NY',
      },
      authOpts(),
    )

    const result = await client().customer.addresses.list(undefined, authOpts())

    expect(result.data.length).toBeGreaterThan(0)
    const address = result.data[0]
    expect(address.id).toMatch(/^addr_/)
    expect(address).toHaveProperty('is_default_billing')
    expect(address).toHaveProperty('is_default_shipping')
    expect(typeof address.is_default_billing).toBe('boolean')
    expect(typeof address.is_default_shipping).toBe('boolean')
  })

  it('creates an address with is_default_billing', async () => {
    const address = await client().customer.addresses.create(
      {
        first_name: 'Integration',
        last_name: 'Test',
        address1: '100 Broadway',
        city: 'New York',
        postal_code: '10005',
        country_iso: 'US',
        state_abbr: 'NY',
        is_default_billing: true,
      },
      authOpts(),
    )

    expect(address.id).toMatch(/^addr_/)
    expect(address.is_default_billing).toBe(true)
    expect(address.city).toBe('New York')
  })

  it('updates an address and sets default shipping', async () => {
    const created = await client().customer.addresses.create(
      {
        first_name: 'Update',
        last_name: 'Test',
        address1: '200 Park Ave',
        city: 'New York',
        postal_code: '10166',
        country_iso: 'US',
        state_abbr: 'NY',
      },
      authOpts(),
    )

    const updated = await client().customer.addresses.update(
      created.id,
      { is_default_shipping: true, city: 'Brooklyn' },
      authOpts(),
    )

    expect(updated.id).toBe(created.id)
    expect(updated.is_default_shipping).toBe(true)
    expect(updated.city).toBe('Brooklyn')
  })
})

describe('customer orders', () => {
  it('completes an order and lists/views it in order history', async () => {
    const creds = getCredentials()
    const c = client()

    const products = await c.products.list()
    const variantId = products.data.find(
      (p) => p.purchasable && p.default_variant_id,
    )!.default_variant_id

    const cart = await c.carts.create(undefined, authOpts())
    const opts = { ...authOpts(), spreeToken: cart.token }

    await c.carts.items.create(cart.id, { variant_id: variantId, quantity: 1 }, opts)

    const address = {
      first_name: 'Order',
      last_name: 'History',
      address1: '1 Times Square',
      city: 'New York',
      postal_code: '10036',
      country_iso: creds.country_iso,
      state_abbr: 'NY',
      phone: '555-0100',
    }
    const withAddr = await c.carts.update(
      cart.id,
      {
        email: creds.user_email,
        shipping_address: address,
        billing_address: address,
      },
      opts,
    )

    const ful = withAddr.fulfillments[0]
    await c.carts.fulfillments.update(
      cart.id,
      ful.id,
      { selected_delivery_rate_id: ful.delivery_rates[0].id },
      opts,
    )
    await c.carts.payments.create(
      cart.id,
      { payment_method_id: creds.check_payment_method_id },
      opts,
    )
    const order = await c.carts.complete(cart.id, opts)

    // List
    const orders = await c.customer.orders.list(undefined, authOpts())
    expect(orders.data.length).toBeGreaterThan(0)
    const found = orders.data.find((o) => o.id === order.id)
    expect(found).toBeDefined()
    expect(found!.number).toBe(order.number)

    // Detail
    const detail = await c.customer.orders.get(order.id, undefined, authOpts())
    expect(detail.id).toBe(order.id)
    expect(detail.completed_at).toBeDefined()
    expect(detail.items.length).toBeGreaterThan(0)
  })
})
