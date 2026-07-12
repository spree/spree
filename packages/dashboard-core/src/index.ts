/// <reference path="./virtual.d.ts" />
// @spree/dashboard-core — Spree Dashboard framework.
//
// The extension API for plugin authors. Consumers import flat from this barrel:
//
//     import { useAuth, defineTable, registerSlot, nav } from '@spree/dashboard-core'
//
// Or use the focused entry points:
//
//     import { defineDashboardPlugin } from '@spree/dashboard-core/plugin'
//     import { AuthProvider } from '@spree/dashboard-core/providers/auth-provider'
//     import { useResourceMutation } from '@spree/dashboard-core/hooks/use-resource-mutation'

// ---------------------------------------------------------------------------
// Admin SDK client (Vite-aware singleton; reads VITE_SPREE_API_URL at build)
// ---------------------------------------------------------------------------
export { adminClient } from './client'
export * from './components/address-form-dialog'
export * from './components/app-sidebar'
export * from './components/bulk-action-bar'
export * from './components/can'
export * from './components/country-combobox'
export * from './components/country-state-fields'
export * from './components/currency-select'
export * from './components/export-button'
export * from './components/file-upload-field'
export * from './components/image-upload-field'
export * from './components/import-button'
export * from './components/locale-select'
export * from './components/market-combobox'
export * from './components/nav-main'
export * from './components/page-header'
export * from './components/page-tabs'
export * from './components/preferences-form'
export * from './components/resource-combobox'
export * from './components/resource-multi-autocomplete'
export * from './components/resource-picker-sheet'
export * from './components/resource-table'
export * from './components/settings-sidebar'
export * from './components/slot'
export * from './components/store-date-picker'
export * from './components/store-switcher'
export * from './components/table-toolbar'
export * from './components/tag-combobox'
export * from './components/top-bar'
// ---------------------------------------------------------------------------
// Infra hooks
// ---------------------------------------------------------------------------
export * from './hooks/use-auth'
export * from './hooks/use-command-palette'
export * from './hooks/use-countries'
export * from './hooks/use-custom-fields'
export * from './hooks/use-direct-upload'
export * from './hooks/use-display-name'
export * from './hooks/use-export'
export * from './hooks/use-global-search'
export * from './hooks/use-host-form'
export * from './hooks/use-import'
export * from './hooks/use-resource-mutation'
export * from './hooks/use-switch-admin-locale'
// ---------------------------------------------------------------------------
// Registries — pluggable extension points (nav, route, slot, table,
// settings-nav, form fields, custom field components)
// ---------------------------------------------------------------------------
export * from './lib/custom-field-components'
// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
export * from './lib/filters-to-ransack'
export * from './lib/form-errors'
export * from './lib/form-fields-registry'
export * from './lib/form-mappers'
export * from './lib/formatters'
// i18n side-effect import bootstraps i18next + React adapter on first import.
// Consumers that need the singleton (e.g. plugin authors calling
// `i18n.addResourceBundle`) get it via the named re-export.
export * from './lib/i18n'
export * from './lib/nav-registry'
export * from './lib/permissions'
export * from './lib/query-client'
export * from './lib/query-keys'
export * from './lib/route-registry'
export * from './lib/search-registry'
export * from './lib/settings-nav-registry'
export * from './lib/slot-registry'
export * from './lib/table-registry'
export { ensureTimestampColumns } from './lib/timestamp-columns'
// ---------------------------------------------------------------------------
// Plugin facade — re-exported for convenience; same API as `/plugin` subpath
// ---------------------------------------------------------------------------
export * from './plugin'
// ---------------------------------------------------------------------------
// Providers — must be mounted by the consuming app shell
// ---------------------------------------------------------------------------
export * from './providers/auth-provider'
export * from './providers/permission-provider'
export * from './providers/store-provider'
