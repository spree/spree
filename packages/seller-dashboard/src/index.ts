// The i18n bootstrap runs on import and must come first: route modules and
// table definitions call `i18n.t(...)` at module load, so a bundler that
// evaluated them before this would bake raw keys into the UI. Side-effect
// imports are ordering barriers, which is exactly what this relies on.
import './i18n'
// The built-in sidebar entries. Registered on import — after i18n, since the
// labels are translated at registration time — and before any host plugin
// runs, so a plugin's `nav.remove('team')` finds the entry to remove.
import './nav/default'

// Plugin facade re-export — lets a marketplace register in-app customisations
// (nav entries, slot widgets, table columns) without declaring
// @spree/dashboard-core as a direct dependency. Same facade the operator's
// dashboard exposes: one API for extending either panel.
export * from '@spree/dashboard-core/plugin'

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
