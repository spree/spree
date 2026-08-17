import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import en from './locales/en.json'

/**
 * The panel's own copy. Deliberately separate from the admin dashboard's:
 * sellers and marketplace staff read different words for the same records —
 * "your products" rather than "products", "your payouts" rather than a
 * seller's.
 */
void i18n.use(initReactI18next).init({
  resources: { en: { translation: en } },
  lng: 'en',
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
})

export default i18n
