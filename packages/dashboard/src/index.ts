// @spree/dashboard — the Spree admin app shell.
//
// Hosts import the shell component and a router built from their own
// generated route tree (see `@spree/dashboard/vite` for the generation):
//
//     import { createDashboardRouter, Dashboard } from '@spree/dashboard'
//
// This module is also the single import an application needs. It re-exports
// the framework (`@spree/dashboard-core`) and the design system
// (`@spree/dashboard-ui`), so a host writing its own pages imports hooks,
// providers, registries and UI primitives from here without having to know
// which package each lives in. Both remain importable directly — plugin
// authors and anyone assembling a bespoke dashboard keep using them, and the
// subpath exports (`@spree/dashboard-ui/icons`, `@spree/dashboard-core/vite`)
// are unaffected.
//
// Order matters. A handful of names exist in both packages: the design system
// ships a presentational component and the framework wraps it with data. The
// framework is exported last so its version wins, which is the one an
// application wants — `ResourceCombobox` that loads its own options rather
// than the pure one that takes them as props. Reach past the facade when you
// want the presentational half:
//
//     import { ResourceCombobox } from '@spree/dashboard-ui'
//
// `pnpm --filter @spree/dashboard test` fails when a new duplicate appears,
// so this list cannot drift silently.

export * from '@spree/dashboard-core'
// `export *` drops a name declared by both modules rather than picking one,
// so the duplicates below are re-exported explicitly. The framework's version
// wins because it is the one an application wants: it fetches its own data,
// where the design system's takes everything as props. Import from
// `@spree/dashboard-ui` directly for the presentational half.
export {
  type DateRange,
  ResourceCombobox,
  type ResourceComboboxProps,
  ResourceMultiAutocomplete,
  type ResourceMultiAutocompleteProps,
  Slot,
  StatusCard,
} from '@spree/dashboard-core'
export * from '@spree/dashboard-ui'

export { createDashboardRouter } from './create-router'
export { Dashboard } from './dashboard'
