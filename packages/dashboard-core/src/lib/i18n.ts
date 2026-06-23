import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
// Relative path, not `@/...`: dashboard-core ships source; the consuming
// project's `@/*` alias is theirs alone (see Phase 1's rationale).
import en from '../locales/en.json'

// localStorage key for the admin's chosen UI language. Shared by the login
// screen (pre-auth), the top-bar switcher, and the profile form so a choice
// made anywhere is honored on the next paint.
export const ADMIN_LOCALE_STORAGE_KEY = 'spree-admin-locale'

// Read the stored locale, tolerating restricted-storage contexts (Safari
// private mode, sandboxed iframes) where `localStorage` access throws. Returns
// `null` when there is no stored choice (or storage is unavailable) so callers
// can distinguish "no choice yet" from an explicit value.
function storedLocale(): string | null {
  try {
    if (typeof localStorage === 'undefined') return null
    return localStorage.getItem(ADMIN_LOCALE_STORAGE_KEY)
  } catch {
    return null
  }
}

function readStoredLocale(): string {
  return storedLocale() || 'en'
}

/**
 * Whether the admin has an explicitly stored UI-language choice (made via the
 * top-bar switcher, the profile form, or a previously-synced account
 * `selected_locale`). Distinguishes "no choice yet" (key absent) from
 * "explicitly chose English" (key present === 'en') — the store-wide
 * `preferred_admin_locale` fallback may only apply when this is false.
 */
export function hasStoredLocale(): boolean {
  return storedLocale() != null
}

// All non-English core bundles, imported EAGERLY so the active language has its
// resources synchronously available (registered just after init() below) —
// no flash, no async race with module-load `i18n.t(...)` calls.
const coreLocales = import.meta.glob<{ default: Record<string, unknown> }>(
  ['../locales/*.json', '!../locales/en.json'],
  { eager: true },
)

/** Admin-UI locale codes the framework ships a bundle for (including `en`). */
export function coreLocaleCodes(): string[] {
  return [
    'en',
    ...Object.keys(coreLocales).map((p) => p.replace('../locales/', '').replace('.json', '')),
  ]
}

// Switch the admin UI language. Persists the choice and reloads the page.
//
// A full reload is deliberate: many labels (table columns, nav, registry
// titles) are resolved with `i18n.t(...)` at module-load time and don't react
// to a live `changeLanguage`. Reloading re-runs those at boot in the new
// language (read from localStorage by `init` below), so every string switches
// — not just the components currently subscribed to i18next.
//
// The reload is deferred to the next macrotask so any pending React state flush
// (e.g. a just-saved form resetting its dirty state) completes first — otherwise
// a still-armed `beforeunload` dirty-guard would trigger the browser's
// "unsaved changes" prompt.
export function switchLocale(code: string): void {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(ADMIN_LOCALE_STORAGE_KEY, code)
  }
  if (typeof window !== 'undefined') {
    setTimeout(() => window.location.reload(), 0)
  }
}

// Bootstrap i18next with the framework's base translation namespace. Side-effect
// import — `import '@spree/dashboard-core/lib/i18n'` from the consuming app's
// entry point runs this once before any component calls `useTranslation()`.
//
// The app (and any plugin) extends the base by calling
// `i18n.addResourceBundle('en', 'translation', extraKeys, true, true)`
// after this side-effect import has settled. The `deep` + `overwrite` flags
// merge the extension into the base namespace without dropping framework keys.
//
// English ships eagerly; `lng` is read from localStorage so a previously
// chosen language is the initial language on first paint (no flash).
i18n.use(initReactI18next).init({
  resources: { en: { translation: en } },
  lng: readStoredLocale(),
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

// Register the eager non-English core bundles now that i18next is initialized.
for (const [path, mod] of Object.entries(coreLocales)) {
  const code = path.replace('../locales/', '').replace('.json', '')
  i18n.addResourceBundle(code, 'translation', mod.default, true, true)
}

// Reflect the active language on the root <html> element so the document
// advertises the right `lang` (a11y, spellcheck, font selection) and `dir`
// (RTL for Arabic/Hebrew/etc.). `i18n.dir()` consults i18next's built-in RTL
// language list. Runs at boot; `switchLocale` reloads the page, so the next
// boot re-applies it for the chosen language — no live listener needed.
function applyDocumentLanguage(code: string): void {
  if (typeof document === 'undefined') return
  const html = document.documentElement
  html.setAttribute('lang', code)
  html.setAttribute('dir', i18n.dir(code))
}

applyDocumentLanguage(i18n.language || readStoredLocale())

/** Document text direction for a locale (`ltr` or `rtl`). */
export function uiDirection(locale?: string): 'ltr' | 'rtl' {
  return i18n.dir(locale ?? i18n.language) === 'rtl' ? 'rtl' : 'ltr'
}

/** Which edge the primary sidebar docks to for a locale. */
export function primarySidebarSide(locale?: string): 'left' | 'right' {
  return uiDirection(locale) === 'rtl' ? 'right' : 'left'
}

export { default as i18n } from 'i18next'
export { Trans, useTranslation } from 'react-i18next'
