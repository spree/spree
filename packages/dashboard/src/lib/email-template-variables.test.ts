import { describe, expect, it } from 'vitest'
import { flattenVariables } from './email-template-variables'

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
