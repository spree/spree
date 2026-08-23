import { afterEach, describe, expect, it } from 'vitest'
import { __getNavEntries, __resetNavRegistry, nav } from '../src/lib/nav-registry'

afterEach(() => {
  __resetNavRegistry()
})

describe('nav registry labels', () => {
  it('accepts an entry defined with labelKey and no literal label', () => {
    nav.add({ key: 'orders', labelKey: 'admin.nav.orders', path: '/orders' })

    expect(__getNavEntries()[0]).toMatchObject({
      key: 'orders',
      labelKey: 'admin.nav.orders',
    })
  })

  it('still accepts a literal label, for plugins without translation bundles', () => {
    nav.add({ key: 'reviews', label: 'Reviews', path: '/reviews' })

    expect(__getNavEntries()[0].label).toBe('Reviews')
  })

  it('rejects an entry carrying neither label nor labelKey', () => {
    expect(() => nav.add({ key: 'nameless', path: '/nameless' })).toThrow(
      /must define either "label" or "labelKey"/,
    )
  })

  it('rejects a patch that strips both label fields off an existing entry', () => {
    nav.add({ key: 'orders', labelKey: 'admin.nav.orders', path: '/orders' })

    expect(() => nav.update('orders', { labelKey: undefined })).toThrow(
      /must define either "label" or "labelKey"/,
    )
  })

  it('rejects an unlabelled child', () => {
    nav.add({ key: 'orders', labelKey: 'admin.nav.orders', path: '/orders' })

    expect(() => nav.addChild('orders', { key: 'orders.drafts', path: '/orders/drafts' })).toThrow(
      /must define either "label" or "labelKey"/,
    )
  })

  it('rejects unlabelled entries inserted relative to another', () => {
    nav.add({ key: 'orders', labelKey: 'admin.nav.orders', path: '/orders' })

    expect(() => nav.insertBefore('orders', { key: 'a', path: '/a' })).toThrow(
      /must define either "label" or "labelKey"/,
    )
    expect(() => nav.insertAfter('orders', { key: 'b', path: '/b' })).toThrow(
      /must define either "label" or "labelKey"/,
    )
  })
})
