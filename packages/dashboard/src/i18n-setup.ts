// i18n bootstrap for `@spree/dashboard`.
//
// 1. The side-effect import below initializes i18next with the framework's
//    base translation namespace (`admin.actions.*`, `admin.common.*`,
//    `admin.fields.<simple>.*`, etc.) shipped in `@spree/dashboard-core`.
// 2. We then merge the app's resource bundle (`admin.nav.*`, resource pages,
//    integrations) so callers can `t('admin.nav.orders')` alongside
//    `t('admin.actions.save')` from the same namespace.
//
// Plugin authors follow the same pattern from their entry module:
//
//     import { i18n } from '@spree/dashboard-core'
//     import myEn from './locales/en.json'
//     i18n.addResourceBundle('en', 'translation', myEn.admin, true, true)
//
// `deep: true` + `overwrite: true` merge nested objects without dropping
// keys the framework already provided; plugin keys win on collision.
import { i18n, intlDisplayName } from '@spree/dashboard-core'
import en from './locales/en.json'

i18n.addResourceBundle('en', 'translation', en, true, true)

// All non-English app bundles, imported EAGERLY so the active one can be
// registered synchronously at module-load — before any table/registry module
// evaluates its `i18n.t(...)` labels. (We reload the page on language change,
// so only the booted language's labels ever need to be resolved; eager keeps
// that resolution synchronous and flash-free. ~19 KB gz per locale.)
const appLocales = import.meta.glob<{ default: Record<string, unknown> }>(
  ['./locales/*.json', '!./locales/en.json'],
  { eager: true },
)

function codeFromPath(path: string): string {
  return path.replace('./locales/', '').replace('.json', '')
}

// Register every app bundle up front so a switched/booted language resolves
// synchronously. (Core bundles are registered the same way in dashboard-core.)
// `lib/i18n.ts` already set the initial `lng` from localStorage, so the booted
// language's resources are present here before any table/registry module
// evaluates its `i18n.t(...)` labels.
for (const [path, mod] of Object.entries(appLocales)) {
  i18n.addResourceBundle(codeFromPath(path), 'translation', mod.default, true, true)
}

// Each language's endonym (its own name: `Deutsch`, `日本語`). `Intl.DisplayNames`
// returns it in the language's own convention, so some are lowercase
// (`français`, `polski`); capitalize the first letter — per the language's own
// casing rules — for a uniform, title-cased list. Scripts without case
// (`日本語`) are unaffected. Falls back to the code on no coverage.
function localeName(code: string): string {
  const name = intlDisplayName('language', code, code) ?? code
  return name.charAt(0).toLocaleUpperCase(code) + name.slice(1)
}

/**
 * Admin UI languages the dashboard can display, as `{ code, name }` pairs for
 * the language picker. Derived from the shipped locale bundles, not the API.
 */
export function getAvailableUiLocales(): Array<{ code: string; name: string }> {
  const codes = ['en', ...Object.keys(appLocales).map(codeFromPath)]
  return codes.map((code) => ({ code, name: localeName(code) }))
}
