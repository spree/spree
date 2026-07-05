import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
// Relative path, not `@/...`: dashboard-core ships source; the consuming
// project's `@/*` alias is theirs alone (see Phase 1's rationale).
import en from '../locales/en.json'

// localStorage key for the admin's chosen UI language. Shared by the login
// screen (pre-auth), the top-bar switcher, and the profile form so a choice
// made anywhere is honored on the next paint.
export const ADMIN_LOCALE_STORAGE_KEY = 'spree-admin-locale'

// Marks the locale key as auto-applied from a store's `preferred_admin_locale`
// (vs an explicit choice). Holds the storeId whose default is currently in
// effect, so crossing into a different store can re-apply that store's default
// while a genuine choice (switcher/profile/login) still wins everywhere. Mirrors
// legacy Rails: the `spree_admin_locale` cookie only ever held an explicit
// login-screen pick; the store default was re-derived per request, never stored.
const ADMIN_LOCALE_AUTO_STORE_KEY = 'spree-admin-locale-auto-store'

function readStorage(key: string): string | null {
  try {
    if (typeof localStorage === 'undefined') return null
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

function writeStorage(key: string, value: string): void {
  try {
    if (typeof localStorage !== 'undefined') localStorage.setItem(key, value)
  } catch {
    // Restricted-storage contexts (Safari private mode, sandboxed iframes) throw
    // on write; the choice still applies for this session via the booted `lng`.
  }
}

function clearStorage(key: string): void {
  try {
    if (typeof localStorage !== 'undefined') localStorage.removeItem(key)
  } catch {
    // Ignore — see writeStorage.
  }
}

// A full reload is deliberate for a language change: many labels (table columns,
// nav, registry titles) are resolved with `i18n.t(...)` at module-load time and
// don't react to a live `changeLanguage`. Reloading re-runs those at boot in the
// new language (read from localStorage by `init`). Deferred to the next macrotask
// so a pending React state flush (e.g. a just-saved form clearing its dirty
// state) completes first — otherwise a still-armed `beforeunload` dirty-guard
// would trigger the browser's "unsaved changes" prompt.
function reloadSoon(): void {
  if (typeof window !== 'undefined') {
    setTimeout(() => window.location.reload(), 0)
  }
}

// Read the stored locale, tolerating restricted-storage contexts where
// `localStorage` access throws. Returns `null` when there is no stored choice
// so callers can distinguish "no choice yet" from an explicit value.
function storedLocale(): string | null {
  return readStorage(ADMIN_LOCALE_STORAGE_KEY)
}

function readStoredLocale(): string {
  return storedLocale() || 'en'
}

/**
 * Reconcile the admin UI language against a store's `preferred_admin_locale`
 * fallback (legacy `base_controller` parity), for an admin with no genuine
 * personal choice. Encodes the precedence:
 *   account selected_locale > genuine stored choice > store preferred_admin_locale > 'en'
 *
 * No-op when a higher tier owns the language (an account locale, or a genuine
 * stored choice — locale key set without an auto-marker). Otherwise drives the
 * stored language to this store's current default:
 *   - a supported default → adopt it (auto-marked to this store);
 *   - a blank/cleared/unsupported default → revert to 'en' IF the prior value was
 *     auto-applied (a stale auto-default from this or another store is dropped);
 *   - already matching → nothing changes.
 * Reloads (via the boot path) only when the displayed language actually changes.
 *
 * @param code        the store's current `preferred_admin_locale`
 * @param storeId     the store being entered
 * @param accountLocale  the account's `selected_locale` (null when unset)
 * @param supported   locale codes the dashboard ships a bundle for
 */
export function reconcileStoreDefaultLocale(
  code: string | null | undefined,
  storeId: string,
  accountLocale: string | null,
  supported: string[],
): void {
  if (accountLocale) return
  const auto = readStorage(ADMIN_LOCALE_AUTO_STORE_KEY)
  const stored = storedLocale()
  // A genuine choice (locale key set, no auto-marker) outranks any store default.
  if (stored != null && auto == null) return

  const target = code && supported.includes(code) ? code : null
  const current = i18n.resolvedLanguage ?? i18n.language

  if (target) {
    writeStorage(ADMIN_LOCALE_STORAGE_KEY, target)
    writeStorage(ADMIN_LOCALE_AUTO_STORE_KEY, storeId)
    if (target !== current) reloadSoon()
  } else if (auto != null) {
    // Store has no usable default and the current language was auto-applied —
    // drop it so the UI reverts to the app default ('en').
    clearStorage(ADMIN_LOCALE_STORAGE_KEY)
    clearStorage(ADMIN_LOCALE_AUTO_STORE_KEY)
    if (current !== 'en') reloadSoon()
  }
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

/**
 * Record an explicit, genuine UI-language choice (top-bar switcher, profile,
 * login, settings-save) WITHOUT reloading. Persists the locale and clears any
 * store-default marker, so the choice now outranks every store default and
 * won't be superseded on store switches. Use this when the UI already displays
 * `code` (no reload needed) but the choice must still be marked as genuine.
 */
export function markGenuineLocaleChoice(code: string): void {
  writeStorage(ADMIN_LOCALE_STORAGE_KEY, code)
  clearStorage(ADMIN_LOCALE_AUTO_STORE_KEY)
}

// Switch the admin UI language from an explicit, genuine choice. Marks it as
// genuine (see `markGenuineLocaleChoice`) and reloads (see `reloadSoon`) so
// every module-load label re-resolves in the new language.
export function switchLocale(code: string): void {
  markGenuineLocaleChoice(code)
  reloadSoon()
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
