// Extends the framework's i18n rather than standing up a second instance.
//
// The side-effect import initialises i18next and registers the framework's
// own copy — the strings baked into shared components like `RowActions` and
// the confirm dialog. A panel that called `init()` itself would win the race
// and leave those components rendering raw keys
// (`admin.row_actions.menu_label`) wherever they appear. It must come first:
// side-effect imports are ordering barriers.
import '@spree/dashboard-core/lib/i18n'
// The instance comes from core too, not a bare `i18next` import: a bundled
// build can resolve a second copy of the package, and `addResourceBundle` on
// that one throws. Core re-exports the object it initialised for exactly this.
import { i18n, localesFromBundlePaths, setUiLocales } from '@spree/dashboard-core'
import en from './locales/en.json'

/**
 * The panel's own copy, layered on top.
 *
 * Deliberately separate from the admin dashboard's: sellers and marketplace
 * staff read different words for the same records — "your products" rather
 * than "products", "your payouts" rather than a seller's. The deep + overwrite
 * flags merge these in without dropping the framework keys underneath.
 */
i18n.addResourceBundle('en', 'translation', en, true, true)

// Every other language, imported EAGERLY so the active one registers
// synchronously at module load — before any table or registry module
// evaluates its `i18n.t(...)` labels. Switching language reloads the page, so
// only the booted language's strings are ever resolved; eager keeps that
// resolution synchronous and flash-free.
const panelLocales = import.meta.glob<{ default: Record<string, unknown> }>(
  ['./locales/*.json', '!./locales/en.json'],
  { eager: true },
)

for (const [path, mod] of Object.entries(panelLocales)) {
  const code = path.replace('./locales/', '').replace('.json', '')
  i18n.addResourceBundle(code, 'translation', mod.default, true, true)
}

setUiLocales(getAvailableUiLocales().map(({ code }) => code))

/**
 * The languages this panel can display, as `{ code, name }` pairs for the
 * account menu and the account dialog. Derived from the locale bundles the
 * panel ships — not from the API, which knows nothing about what the client
 * can render.
 */
export function getAvailableUiLocales(): Array<{ code: string; name: string }> {
  return localesFromBundlePaths(Object.keys(panelLocales))
}

export default i18n
