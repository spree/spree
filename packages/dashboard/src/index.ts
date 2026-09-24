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
// A handful of names exist in both packages, where the design system ships a
// presentational component and the framework wraps it with data. Reach past
// the facade when you want the presentational half:
//
//     import { ResourceCombobox } from '@spree/dashboard-ui'
//
// `pnpm --filter @spree/dashboard test` checks that every such name resolves
// to the framework, so a reordering or a new duplicate cannot change the
// public API unnoticed.

export * from '@spree/dashboard-core'
// `export *` from two modules that both declare a name is an error (TS2308),
// and the ambiguity is resolved by naming the winner explicitly. The
// framework's version wins: it fetches its own data, where the design
// system's takes everything as props. `pnpm test` checks every duplicate
// resolves this way, so a new one cannot slip in unnoticed.
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
