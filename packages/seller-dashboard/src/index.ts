// The i18n bootstrap runs on import and must come first: route modules and
// table definitions call `i18n.t(...)` at module load, so a bundler that
// evaluated them before this would bake raw keys into the UI. Side-effect
// imports are ordering barriers, which is exactly what this relies on.
import './i18n'

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
