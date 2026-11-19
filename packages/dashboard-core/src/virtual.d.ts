// Ambient declaration for the module synthesized by `spreeDashboardPlugin()`
// (see src/vite/index.ts). Referenced from src/index.ts so any program that
// imports @spree/dashboard-core can `import 'virtual:spree-dashboard-plugins'`
// without its own shim.
declare module 'virtual:spree-dashboard-plugins'

// The host's installed `@spree/*` versions, defined by `spreeDashboardPlugin()`.
// Undefined in a build without the plugin, so read it behind a typeof check.
declare const __SPREE_PACKAGES__: Record<string, string> | undefined
