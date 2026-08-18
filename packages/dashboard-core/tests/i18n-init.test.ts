import { createInstance } from 'i18next'
import { describe, expect, it, vi } from 'vitest'

/**
 * `reconcileStoreDefaultLocale` decides whether to reload the page by comparing
 * the store's language against `i18n.resolvedLanguage`. That comparison is only
 * meaningful if the stored language actually resolved — and it resolves to the
 * fallback when its bundle is missing at `init()` time.
 *
 * Registering bundles after init leaves `resolvedLanguage` on 'en' forever, so
 * the reconciler sees a mismatch on every boot and reloads in a loop. These
 * tests pin the ordering that avoids it.
 */
describe('i18n initialization ordering', () => {
  it('resolves a non-English language when its bundle is present at init', async () => {
    const i18n = createInstance()
    await i18n.init({
      resources: {
        en: { translation: { hello: 'Hello' } },
        pl: { translation: { hello: 'Cześć' } },
      },
      lng: 'pl',
      fallbackLng: 'en',
    })

    expect(i18n.resolvedLanguage).toBe('pl')
    expect(i18n.t('hello')).toBe('Cześć')
  })

  it('falls back to English when the bundle is registered only after init', async () => {
    const i18n = createInstance()
    await i18n.init({
      resources: { en: { translation: { hello: 'Hello' } } },
      lng: 'pl',
      fallbackLng: 'en',
    })
    i18n.addResourceBundle('pl', 'translation', { hello: 'Cześć' }, true, true)

    // The bundle is there, but the language resolved before it arrived — this
    // is the state that made the reconciler reload endlessly.
    expect(i18n.resolvedLanguage).toBe('en')
  })

  it('resolves the stored language, so the reconciler sees no mismatch', async () => {
    // A store whose admin language is Polish, already adopted and persisted.
    // The module reads this at import time to pick its initial language.
    const store = new Map([
      ['spree-admin-locale', 'pl'],
      ['spree-admin-locale-auto-store', 'store_1'],
    ])
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => store.get(key) ?? null,
      setItem: (key: string, value: string) => store.set(key, value),
      removeItem: (key: string) => store.delete(key),
    })

    const { i18n, coreLocaleCodes } = await import('../src/lib/i18n')

    expect(coreLocaleCodes()).toContain('pl')
    // The guard inside reconcileStoreDefaultLocale is `target !== current`,
    // where current is this value. It must equal the stored language or the
    // page reloads on every boot, forever.
    expect(i18n.resolvedLanguage ?? i18n.language).toBe('pl')
  })
})
