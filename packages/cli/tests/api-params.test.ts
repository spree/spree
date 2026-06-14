import { describe, expect, it } from 'vitest'
import { buildParams, normalizePath } from '../src/api/params'

describe('buildParams', () => {
  it('wraps -q expressions into Ransack q[...] params', () => {
    expect(buildParams({ query: ['status_eq=active', 'name_cont=shirt'] })).toEqual({
      'q[status_eq]': 'active',
      'q[name_cont]': 'shirt',
    })
  })

  it('turns a repeated key into a []-suffixed array param so Rack keeps every value', () => {
    expect(buildParams({ query: ['id_in=prod_a', 'id_in=prod_b'] })).toEqual({
      'q[id_in][]': ['prod_a', 'prod_b'],
    })
  })

  it('passes pagination and shaping flags through', () => {
    expect(
      buildParams({
        query: [],
        sort: '-created_at',
        page: '2',
        limit: '50',
        expand: 'variants',
        fields: 'id,name',
      }),
    ).toEqual({
      sort: '-created_at',
      page: 2,
      limit: 50,
      expand: 'variants',
      fields: 'id,name',
    })
  })

  it('keeps = inside values', () => {
    expect(buildParams({ query: ['name_cont=a=b'] })).toEqual({ 'q[name_cont]': 'a=b' })
  })

  it('rejects expressions without key=value shape', () => {
    expect(() => buildParams({ query: ['status_eq'] })).toThrow(/Invalid -q expression/)
  })

  it('rejects non-numeric --page / --limit', () => {
    expect(() => buildParams({ query: [], page: 'abc' })).toThrow(/Invalid --page/)
    expect(() => buildParams({ query: [], limit: '0' })).toThrow(/Invalid --limit/)
  })
})

describe('normalizePath', () => {
  it('adds a leading slash', () => {
    expect(normalizePath('products')).toBe('/products')
  })

  it('strips a pasted /api/v3/admin prefix', () => {
    expect(normalizePath('/api/v3/admin/orders/ord_x')).toBe('/orders/ord_x')
  })

  it('leaves clean paths alone', () => {
    expect(normalizePath('/orders/ord_x/refunds')).toBe('/orders/ord_x/refunds')
  })

  it('only strips the prefix at a segment boundary', () => {
    // A resource that merely starts with the prefix string must not be mangled.
    expect(normalizePath('/api/v3/administration')).toBe('/api/v3/administration')
  })
})
