import { describe, expect, it } from 'vitest'
import { importTypeIndexPath, importTypeKey, isImportActive } from './import-types'

describe('importTypeKey', () => {
  it('demodulizes and underscores the STI type', () => {
    expect(importTypeKey('Spree::Imports::Products')).toBe('products')
    expect(importTypeKey('Spree::Imports::Customers')).toBe('customers')
    expect(importTypeKey('Spree::Imports::ProductTranslations')).toBe('product_translations')
  })

  it('returns an empty string for null', () => {
    expect(importTypeKey(null)).toBe('')
  })
})

describe('importTypeIndexPath', () => {
  it('routes customers imports to the customers index', () => {
    expect(importTypeIndexPath('Spree::Imports::Customers')).toBe('/$storeId/customers')
  })

  it('routes product-ish imports to the products index', () => {
    expect(importTypeIndexPath('Spree::Imports::Products')).toBe('/$storeId/products')
    expect(importTypeIndexPath('Spree::Imports::ProductTranslations')).toBe('/$storeId/products')
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
