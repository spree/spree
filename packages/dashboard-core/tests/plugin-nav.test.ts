import { beforeEach, describe, expect, it } from 'vitest'
import { __getNavEntries, __resetNavRegistry, nav } from '../src/lib/nav-registry'
import { defineDashboardPlugin } from '../src/plugin'

function entryKeys(): string[] {
  return __getNavEntries().map((e) => e.key)
}

describe('defineDashboardPlugin nav', () => {
  beforeEach(() => {
    __resetNavRegistry()
    // Stand-ins for built-in entries, registered before any plugin runs —
    // same order as the real bootstrap.
    nav.add({ key: 'orders', label: 'Orders', path: '/orders', position: 20 })
    nav.add({ key: 'products', label: 'Products', path: '/products', position: 30 })
  })

  it('array form adds entries (shorthand for { add })', () => {
    defineDashboardPlugin({
      nav: [{ key: 'reviews', label: 'Reviews', path: '/reviews', position: 35 }],
    })
    expect(entryKeys()).toEqual(['orders', 'products', 'reviews'])
  })

  it('object form adds, removes, and patches entries', () => {
    defineDashboardPlugin({
      nav: {
        add: [{ key: 'reviews', label: 'Reviews', path: '/reviews' }],
        remove: ['orders'],
        update: { products: { label: 'Catalog', position: 5 } },
      },
    })
    expect(entryKeys()).toEqual(['products', 'reviews'])
    const products = __getNavEntries().find((e) => e.key === 'products')
    expect(products?.label).toBe('Catalog')
    expect(products?.position).toBe(5)
  })

  it('removing an unknown key is a no-op; patching one throws', () => {
    expect(() => defineDashboardPlugin({ nav: { remove: ['nope'] } })).not.toThrow()
    expect(() => defineDashboardPlugin({ nav: { update: { nope: { label: 'X' } } } })).toThrow(
      /not found/,
    )
  })

  it('collects every failure before throwing', () => {
    expect(() =>
      defineDashboardPlugin({
        nav: {
          add: [{ key: 'orders', label: 'Dup', path: '/dup' }],
          update: { nope: { label: 'X' } },
        },
      }),
    ).toThrow(AggregateError)
    // The valid parts of a partially-failing config still land — nothing
    // rolled back, matching the documented all-errors-at-once behavior.
    expect(entryKeys()).toEqual(['orders', 'products'])
  })
})
