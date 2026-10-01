import type { TemplateVars } from './template.js'

declare const __SPREE_PLUGIN_PEER_RANGES__: TemplateVars

/**
 * `@spree/admin-sdk` and `@spree/dashboard-*` peer ranges for a scaffolded
 * plugin, derived from the workspace versions when this CLI was built (see
 * scripts/plugin-peer-ranges.mjs) so they never lag behind a release.
 */
export const PLUGIN_PEER_RANGES: TemplateVars = __SPREE_PLUGIN_PEER_RANGES__
