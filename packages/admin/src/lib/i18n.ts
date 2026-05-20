import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import en from '@/locales/en.json'

// English-only at launch. Adding another locale = add a `<code>.json` next to
// `en.json` and load it here. Lazy chunks come later if/when the locale list
// grows enough to matter.
i18n.use(initReactI18next).init({
  resources: { en: { translation: en } },
  lng: 'en',
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
  // Surface missing keys in dev so we notice gaps as we build pages; ship
  // silently humanizing the attribute in prod (a missing key shouldn't blow
  // up the UI).
  saveMissing: import.meta.env.DEV,
  missingKeyHandler: import.meta.env.DEV
    ? (_lngs, _ns, key) => console.warn(`[i18n] Missing key: ${key}`)
    : undefined,
})

export { default as i18n } from 'i18next'
export { Trans, useTranslation } from 'react-i18next'
