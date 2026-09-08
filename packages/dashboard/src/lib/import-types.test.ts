import { describe, expect, it } from 'vitest'
import { importTypeDestination, importTypeKey, isImportActive } from './import-types'

describe('importTypeKey', () => {
  it('passes the API shorthand through unchanged', () => {
    expect(importTypeKey('products')).toBe('products')
    expect(importTypeKey('customers')).toBe('customers')
    expect(importTypeKey('product_translations')).toBe('product_translations')
  })

  // Older servers (and payloads cached before the shorthand landed) send the
  // Ruby class name.
  it('demodulizes and underscores a legacy STI type', () => {
    expect(importTypeKey('Spree::Imports::Products')).toBe('products')
    expect(importTypeKey('Spree::Imports::Customers')).toBe('customers')
    expect(importTypeKey('Spree::Imports::ProductTranslations')).toBe('product_translations')
  })

  it('returns an empty string for null', () => {
    expect(importTypeKey(null)).toBe('')
  })
})

describe('importTypeDestination', () => {
  it('routes customers imports to the customers index', () => {
    expect(importTypeDestination('customers')).toEqual({ to: '/$storeId/customers' })
    expect(importTypeDestination('Spree::Imports::Customers')).toEqual({
      to: '/$storeId/customers',
    })
  })

  it('routes product-ish imports to the products index', () => {
    expect(importTypeDestination('products')).toEqual({ to: '/$storeId/products' })
    expect(importTypeDestination('product_translations')).toEqual({ to: '/$storeId/products' })
    expect(importTypeDestination('Spree::Imports::Products')).toEqual({ to: '/$storeId/products' })
  })

  // The rows a price-list import wrote live on one list, so that list's page
  // is where "View records" goes; without the id, the lists index.
  it('routes a price-list import to the list it wrote into', () => {
    expect(importTypeDestination('price_list_prices', { price_list_id: 'pl_1' } as never)).toEqual({
      to: '/$storeId/products/price-lists/$priceListId',
      params: { priceListId: 'pl_1' },
    })
    expect(importTypeDestination('price_list_prices')).toEqual({
      to: '/$storeId/products/price-lists',
    })
  })
})

describe('isImportActive', () => {
  it('is true only while the pipeline is running', () => {
    expect(isImportActive('completed_mapping')).toBe(true)
    expect(isImportActive('processing')).toBe(true)
  })

  it('is false for mapping, terminal statuses and undefined', () => {
    expect(isImportActive('pending')).toBe(false)
    expect(isImportActive('mapping')).toBe(false)
    expect(isImportActive('completed')).toBe(false)
    expect(isImportActive('failed')).toBe(false)
    expect(isImportActive(undefined)).toBe(false)
  })
})
