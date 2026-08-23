import { describe, expect, it } from 'vitest'
import { type SettingsNavEntry, settingsEntryMatches } from '../src/lib/settings-nav-registry'

/** Stands in for i18next — returns the last segment of the key. */
const t = (key: string) => key.split('.').pop() ?? key

const taxRates: SettingsNavEntry = {
  key: 'settings.tax-rates',
  labelKey: 'admin.settings_nav.items.tax_rates',
  descriptionKey: 'admin.settings_nav.descriptions.rates_per_region',
  keywords: ['vat', 'gst', 'sales tax'],
  path: '/tax-rates',
  group: 'selling',
}

describe('settingsEntryMatches', () => {
  it('matches on a keyword the label does not contain', () => {
    expect(settingsEntryMatches(taxRates, 'vat', t)).toBe(true)
    expect(settingsEntryMatches(taxRates, 'gst', t)).toBe(true)
  })

  it('matches on the resolved label', () => {
    expect(settingsEntryMatches(taxRates, 'tax_rates', t)).toBe(true)
  })

  it('matches on the resolved description', () => {
    expect(settingsEntryMatches(taxRates, 'region', t)).toBe(true)
  })

  it('ignores case and surrounding space', () => {
    expect(settingsEntryMatches(taxRates, '  VAT ', t)).toBe(true)
  })

  it('rejects a term appearing nowhere', () => {
    expect(settingsEntryMatches(taxRates, 'webhooks', t)).toBe(false)
  })

  it('treats a blank term as matching everything, so an empty box hides nothing', () => {
    expect(settingsEntryMatches(taxRates, '', t)).toBe(true)
    expect(settingsEntryMatches(taxRates, '   ', t)).toBe(true)
  })

  it('handles an entry with a literal label and no keywords', () => {
    const plugin: SettingsNavEntry = {
      key: 'p',
      label: 'Reviews',
      path: '/reviews',
      group: 'store',
    }

    expect(settingsEntryMatches(plugin, 'review', t)).toBe(true)
    expect(settingsEntryMatches(plugin, 'vat', t)).toBe(false)
  })
})
