import { beforeEach, describe, expect, it } from 'vitest'
import { __getNavEntries, __resetNavRegistry, nav } from '../src/lib/nav-registry'
import { defineDashboardPlugin } from '../src/plugin'

function entryKeys(): string[] {
  return __getNavEntries().map((e) => e.key)
}

function childKeys(parentKey: string): string[] {
  return (__getNavEntries().find((e) => e.key === parentKey)?.children ?? []).map((c) => c.key)
}

describe('defineDashboardPlugin nav', () => {
  beforeEach(() => {
    __resetNavRegistry()
    // Stand-ins for built-in entries, registered before any plugin runs —
    // same order as the real bootstrap. Products carries a built-in child so
    // child-append can be checked for preservation.
    nav.add({ key: 'orders', label: 'Orders', path: '/orders', position: 20 })
    nav.add({
      key: 'products',
      label: 'Products',
      path: '/products',
      position: 30,
      children: [{ key: 'products.categories', label: 'Categories', path: '/products/categories' }],
    })
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

  it('addChildren nests under a built-in parent, preserving its children', () => {
    defineDashboardPlugin({
      nav: {
        addChildren: {
          products: [{ key: 'products.brands', label: 'Brands', path: '/products/brands' }],
        },
      },
    })
    expect(childKeys('products')).toEqual(['products.categories', 'products.brands'])
  })

  it('can add a parent and nest under it in the same config', () => {
    defineDashboardPlugin({
      nav: {
        add: [{ key: 'catalog', label: 'Catalog', path: '/catalog' }],
        addChildren: {
          catalog: [{ key: 'catalog.brands', label: 'Brands', path: '/catalog/brands' }],
        },
      },
    })
    expect(childKeys('catalog')).toEqual(['catalog.brands'])
  })

  it('nesting under an unknown parent throws', () => {
    expect(() =>
      defineDashboardPlugin({
        nav: { addChildren: { nope: [{ key: 'x', label: 'X', path: '/x' }] } },
      }),
    ).toThrow(/not found/)
  })
})

describe('nav child mutators', () => {
  beforeEach(() => {
    __resetNavRegistry()
    nav.add({
      key: 'products',
      label: 'Products',
      path: '/products',
      children: [{ key: 'products.categories', label: 'Categories', path: '/products/categories' }],
    })
  })

  it('removeChild removes only the named child', () => {
    nav.addChild('products', { key: 'products.brands', label: 'Brands', path: '/products/brands' })
    nav.removeChild('products', 'products.categories')
    expect(childKeys('products')).toEqual(['products.brands'])
  })

  it('removeChild is a no-op for unknown parent or child', () => {
    expect(() => nav.removeChild('nope', 'x')).not.toThrow()
    expect(() => nav.removeChild('products', 'nope')).not.toThrow()
    expect(childKeys('products')).toEqual(['products.categories'])
  })

  it('updateChild patches an existing child; throws when missing', () => {
    nav.updateChild('products', 'products.categories', { label: 'Collections', position: 5 })
    const child = __getNavEntries()
      .find((e) => e.key === 'products')
      ?.children?.find((c) => c.key === 'products.categories')
    expect(child?.label).toBe('Collections')
    expect(child?.position).toBe(5)
    expect(() => nav.updateChild('products', 'nope', { label: 'X' })).toThrow(/not found/)
  })

  it('addChild rejects a duplicate child key', () => {
    expect(() =>
      nav.addChild('products', {
        key: 'products.categories',
        label: 'Dup',
        path: '/dup',
      }),
    ).toThrow(/already exists/)
  })
})
