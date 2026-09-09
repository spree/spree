import i18n from 'i18next'
import { beforeAll, describe, expect, it } from 'vitest'
import { permissionGroupLabel, typeDescription, typeLabel } from './type-labels'

beforeAll(async () => {
  await i18n.init({
    lng: 'en',
    resources: {
      en: {
        translation: {
          admin: {
            types: {
              promotion_rule: {
                item_total: { name: 'Item total', description: 'Order total meets these criteria' },
                // A type whose translation names it but says nothing more.
                first_order: { name: 'First order' },
              },
              permission_group: { catalog: { name: 'Catalog' } },
            },
          },
        },
      },
    },
  })
})

describe('typeLabel', () => {
  it('prefers the translation over the API label', () => {
    expect(typeLabel('promotion_rule', 'item_total', 'Item Total (from API)')).toBe('Item total')
  })

  it('falls back to the API label for a type it has no translation for', () => {
    // The extension case: a gem ships a Ruby rule but no dashboard locales.
    expect(typeLabel('promotion_rule', 'wishlist_count', 'Wishlist count')).toBe('Wishlist count')
  })

  it('falls back to the code when the API sends nothing usable', () => {
    expect(typeLabel('promotion_rule', 'wishlist_count')).toBe('wishlist_count')
    expect(typeLabel('promotion_rule', 'wishlist_count', '   ')).toBe('wishlist_count')
  })
})

describe('typeDescription', () => {
  it('prefers the translation over the API description', () => {
    expect(typeDescription('promotion_rule', 'item_total', 'from API')).toBe(
      'Order total meets these criteria',
    )
  })

  it('falls back to the API description when only the name is translated', () => {
    expect(typeDescription('promotion_rule', 'first_order', 'Must be their first order')).toBe(
      'Must be their first order',
    )
  })

  it('returns an empty string rather than the code when nothing describes the type', () => {
    // Descriptions are optional helper copy — a bare code would read as noise.
    expect(typeDescription('promotion_rule', 'wishlist_count')).toBe('')
  })
})

describe('permissionGroupLabel', () => {
  it('translates a known group and falls back for an unknown one', () => {
    expect(permissionGroupLabel('catalog', 'Catalog (API)')).toBe('Catalog')
    expect(permissionGroupLabel('logistics', 'Logistics')).toBe('Logistics')
    expect(permissionGroupLabel('logistics')).toBe('logistics')
  })
})
