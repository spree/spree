import i18n from 'i18next'
import { beforeAll, describe, expect, it } from 'vitest'
import { typeLabel } from '../src/lib/type-labels'
import { defineDashboardPlugin } from '../src/plugin'

beforeAll(async () => {
  await i18n.init({
    lng: 'en',
    resources: {
      en: {
        translation: {
          admin: {
            types: { promotion_rule: { item_total: { name: 'Item total' } } },
            actions: { save: 'Save' },
          },
        },
      },
    },
  })
})

describe('defineDashboardPlugin locales', () => {
  it('lets a plugin name the types it registers, without dropping built-in keys', () => {
    defineDashboardPlugin({
      locales: {
        en: {
          admin: {
            types: { promotion_rule: { wishlist_count: { name: 'On a wishlist' } } },
          },
        },
      },
    })

    // The plugin's own type now reads as words rather than the API's fallback.
    expect(typeLabel('promotion_rule', 'wishlist_count', 'Wishlist count')).toBe('On a wishlist')
    // Merged, not replaced: sibling and unrelated keys survive.
    expect(typeLabel('promotion_rule', 'item_total')).toBe('Item total')
    expect(i18n.t('admin.actions.save')).toBe('Save')
  })

  it('registers each language it is given', () => {
    defineDashboardPlugin({
      locales: {
        de: { admin: { types: { promotion_rule: { loyalty_tier: { name: 'Treuestufe' } } } } },
      },
    })

    expect(
      i18n.getResource('de', 'translation', 'admin.types.promotion_rule.loyalty_tier.name'),
    ).toBe('Treuestufe')
  })
})
