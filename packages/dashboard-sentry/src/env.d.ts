interface ImportMetaEnv {
  readonly VITE_SENTRY_DSN?: string
  readonly VITE_SENTRY_ENVIRONMENT?: string
  readonly VITE_SENTRY_RELEASE?: string
  readonly VITE_SENTRY_ENABLE_IN_DEVELOPMENT?: string
}

// Installed `@spree/*` packages by version, defined by the dashboard's Vite plugin.
declare const __SPREE_PACKAGES__: Record<string, string> | undefined
