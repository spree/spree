import i18n from 'i18next'
import { afterEach, beforeAll, describe, expect, it } from 'vitest'
import { formatStoreDate, formatStoreDateTime } from './formatters'

describe('store date formatters', () => {
  beforeAll(async () => {
    if (!i18n.isInitialized) await i18n.init({ lng: 'en', resources: {} })
  })

  afterEach(async () => {
    await i18n.changeLanguage('en')
  })

  it('formats in the store timezone', () => {
    expect(formatStoreDate('2026-03-01T23:30:00Z', 'Europe/Warsaw')).toBe('Mar 2, 2026')
  })

  it('names the month in the admin UI language', async () => {
    await i18n.changeLanguage('de')

    expect(formatStoreDate('2026-03-02T12:00:00Z', 'UTC')).toBe('2. März 2026')
    expect(formatStoreDateTime('2026-03-02T12:00:00Z', 'UTC')).toBe('2. März 2026 12:00')
  })
})
