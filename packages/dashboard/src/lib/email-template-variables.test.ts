import { describe, expect, it } from 'vitest'
import { documentedPaths, flattenVariables } from './email-template-variables'

describe('flattenVariables', () => {
  it('lists dotted paths with samples, reading a list through its first item', () => {
    const paths = flattenVariables({
      order: { number: 'R123', items: [{ name: 'Shirt' }, { name: 'Hat' }], note: null },
      resend: false,
    })

    expect(paths).toEqual([
      { path: 'order', sample: '{…}' },
      { path: 'order.number', sample: 'R123' },
      { path: 'order.items', sample: '[2]' },
      { path: 'order.items.name', sample: 'Shirt' },
      { path: 'order.note', sample: 'null' },
      { path: 'resend', sample: 'false' },
    ])
  })

  it('stops descending past a few levels', () => {
    const deep = { a: { b: { c: { d: { e: { f: 1 } } } } } }

    expect(flattenVariables(deep).map((entry) => entry.path)).not.toContain('a.b.c.d.e.f')
  })
})

describe('documentedPaths', () => {
  it('suggests address fields even when the sample order has no address', () => {
    const paths = documentedPaths('spree.order_mailer.confirm_email')

    expect(paths).toContain('order.billing_address.first_name')
    expect(paths).toContain('order.shipping_address.city')
    expect(paths).toContain('store.name')
    expect(paths).toContain('order.payments.payment_method.name')
    // Email data is serialized with Store API shapes, never admin-only fields.
    expect(paths).not.toContain('order.billing_address.metadata')
  })
})
