import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
// Relative path, not `@/...`: dashboard-core ships source; the consuming
// project's `@/*` alias is theirs alone (see Phase 1's rationale).
import en from '../locales/en.json'

// Bootstrap i18next with the framework's base translation namespace. Side-effect
// import — `import '@spree/dashboard-core/lib/i18n'` from the consuming app's
// entry point runs this once before any component calls `useTranslation()`.
//
// The app (and any plugin) extends the base by calling
// `i18n.addResourceBundle('en', 'translation', extraKeys, true, true)`
// after this side-effect import has settled. The `deep` + `overwrite` flags
// merge the extension into the base namespace without dropping framework keys.
//
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
