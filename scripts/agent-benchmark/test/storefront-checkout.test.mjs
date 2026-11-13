import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { orderMismatch, pageProblems } from '../tasks/storefront-checkout.mjs'

describe('storefront checkout order check', () => {
  const submitted = { variantId: 'variant_abc', quantity: 1, email: 'ada@example.com' }
  const order = (overrides = {}) => ({
    email: 'ada@example.com',
    items: [{ variant_id: 'variant_abc', quantity: 1 }],
    ...overrides,
  })

  it('accepts the order that was submitted', () => {
    assert.equal(orderMismatch(order(), submitted), null)
  })

  it('rejects an order with another email', () => {
    assert.match(orderMismatch(order({ email: 'old@example.com' }), submitted), /email/)
  })

  it('rejects an order with another item, quantity or extra items', () => {
    for (const items of [
      [{ variant_id: 'variant_other', quantity: 1 }],
      [{ variant_id: 'variant_abc', quantity: 2 }],
      [
        { variant_id: 'variant_abc', quantity: 1 },
        { variant_id: 'variant_other', quantity: 1 },
      ],
      [],
    ]) {
      assert.match(orderMismatch(order({ items }), submitted), /items/)
    }
  })
})

describe('storefront checkout page check', () => {
  const pages = {
    '/': '<a href="/products/benchmark-mug">Benchmark Mug</a>',
    '/products/benchmark-mug': '<h1>Benchmark Mug</h1>',
    '/cart': '<p>Your cart is empty.</p>',
    '/checkout': '<p>Your cart is empty.</p>',
    '/orders/or_1?token=abc': '<p>Order <!-- -->R123456789<!-- --> is placed.</p>',
  }
  const shop =
    (overrides = {}) =>
    async (path) => {
      const all = { ...pages, ...overrides }
      return path in all && all[path] !== null
        ? { status: 200, text: all[path] }
        : { status: 404, text: 'Not found' }
    }
  const expected = {
    productName: 'Benchmark Mug',
    productPaths: ['/products/benchmark-mug', '/products/prod_1'],
    orderNumber: 'R123456789',
    confirmationUrl: '/orders/or_1?token=abc',
  }

  it('accepts a shop whose pages all answer', async () => {
    assert.equal(await pageProblems(shop(), expected), null)
  })

  it('accepts a product page at the product id instead of the slug', async () => {
    const byId = shop({
      '/products/benchmark-mug': null,
      '/products/prod_1': '<h1>Benchmark Mug</h1>',
    })
    assert.equal(await pageProblems(byId, expected), null)
  })

  it('names each missing or empty page', async () => {
    const problems = await pageProblems(
      shop({ '/': '<p>Loading…</p>', '/products/benchmark-mug': null, '/cart': null }),
      expected,
    )
    assert.match(problems, /product listing \(\/\) does not show "Benchmark Mug"/)
    assert.match(problems, /product page \(\/products\/prod_1\) answered 404/)
    assert.match(problems, /cart page \(\/cart\) answered 404/)
    assert.doesNotMatch(problems, /checkout page/)
  })

  it('rejects a confirmation page without the order number', async () => {
    const problems = await pageProblems(
      shop({ '/orders/or_1?token=abc': '<p>Thanks!</p>' }),
      expected,
    )
    assert.match(problems, /confirmation page .* does not show "R123456789"/)
  })

  it('rejects a confirmationUrl that is missing or points off the shop', async () => {
    for (const confirmationUrl of [undefined, 'https://example.com/x', '//example.com/x']) {
      const problems = await pageProblems(shop(), { ...expected, confirmationUrl })
      assert.match(problems, /is not a path on the shop/)
    }
  })

  it('reports a page that cannot be fetched', async () => {
    const failing = async (path) => {
      if (path === '/checkout') throw new Error('socket hang up')
      return shop()(path)
    }
    assert.match(await pageProblems(failing, expected), /checkout page .* failed: socket hang up/)
  })
})
