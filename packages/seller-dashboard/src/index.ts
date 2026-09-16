// The i18n bootstrap runs on import and must come first: route modules and
// table definitions call `i18n.t(...)` at module load, so a bundler that
// evaluated them before this would bake raw keys into the UI. Side-effect
// imports are ordering barriers, which is exactly what this relies on.
import './i18n'
// The built-in sidebar entries. Registered on import — after i18n, since the
// labels are translated at registration time — and before any host plugin
// runs, so a plugin's `nav.remove('team')` finds the entry to remove.
import './nav/default'
import './nav/settings'

export * from '@spree/dashboard-core'
export {
  type DateRange,
  ResourceCombobox,
  type ResourceComboboxProps,
  ResourceMultiAutocomplete,
  type ResourceMultiAutocompleteProps,
  Slot,
  StatusCard,
} from '@spree/dashboard-core'
// The single import a marketplace needs: the framework
// (`@spree/dashboard-core`) and the design system (`@spree/dashboard-ui`),
// re-exported so a host writing its own pages never has to work out which
// package an export lives in. Both stay importable directly.
//
// `export *` drops a name declared by both rather than picking one, so the
// duplicates are re-exported explicitly below, resolving to the framework's
// version — the one that fetches its own data. Import from
// `@spree/dashboard-ui` for the presentational half.
export * from '@spree/dashboard-ui'

export {
  createSellerApiClient,
  rememberedSeller,
  rememberSeller,
  setActiveSeller,
} from './api-client'
export { CenteredMessage } from './components/centered-message'
export type { SellerRouterOptions } from './create-router'
export { createSellerRouter } from './create-router'
export { SellerDashboard } from './seller-dashboard'
