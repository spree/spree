// @spree/dashboard-ui — Spree Dashboard design system.
//
// Shadcn primitives + headless composed components + design tokens.
// Consumers import flat from this barrel:
//
//     import { Button, Card, PageHeader } from '@spree/dashboard-ui'
//
// Or import a specific file (for forking, lazy-loading, or to skip the barrel):
//
//     import { Button } from '@spree/dashboard-ui/ui/button'
//
// CSS lives at `@spree/dashboard-ui/styles.css` — import once from your Vite app.

export * from './hooks/use-copy-to-clipboard'
export { useIsMobile } from './hooks/use-mobile'
export * from './hooks/use-scrolled'
// ---------------------------------------------------------------------------
// Helpers + hooks
// ---------------------------------------------------------------------------
export { cn } from './lib/utils'
export { requiredMessage } from './lib/validation-messages'
// ---------------------------------------------------------------------------
// Spree composed components — headless, accept data via props
// ---------------------------------------------------------------------------
export * from './spree/address-block'
export * from './spree/back-button'
export * from './spree/bulk-dialog'
export * from './spree/bulk-price-table'
export * from './spree/calculator-summary'
export * from './spree/color-picker'
export * from './spree/confirm-dialog'
export * from './spree/copy-to-clipboard-button'
export * from './spree/country-flag'
export * from './spree/data-grid'
export * from './spree/drag-handle'
export * from './spree/form-actions'
// JsonPreviewDrawer and JsonValueView are intentionally NOT re-exported from
// this barrel: they pull in `@uiw/react-json-view` (~30KB gzip), and
// code-splitting only works when consumers can deep-import via
// `@spree/dashboard-ui/spree/json-preview-drawer` and
// `@spree/dashboard-ui/spree/json-value-view`. Types are available the same
// way — `import { type JsonPreviewDrawerProps } from '@spree/dashboard-ui/spree/json-preview-drawer'`.

export * from './spree/metadata/metadata-card'
export * from './spree/relative-time'
export * from './spree/resource-combobox'
export * from './spree/resource-layout'
export * from './spree/resource-multi-autocomplete'
export * from './spree/resource-name-cell'
export * from './spree/route-error-boundary'
export * from './spree/row-actions'
export * from './spree/row-click-bridge'
export * from './spree/secret-input'
export * from './spree/storefront-visible-switch'
export * from './spree/tag-list'
export * from './spree/theme-provider'
export * from './spree/theme-toggle'
// ---------------------------------------------------------------------------
// UI primitives (shadcn) — see ./ui/*
// ---------------------------------------------------------------------------
export * from './ui/avatar'
export * from './ui/badge'
export * from './ui/breadcrumb'
export * from './ui/button'
export * from './ui/calendar'
export * from './ui/card'
export * from './ui/chart'
export * from './ui/checkbox'
export * from './ui/collapsible'
export * from './ui/combobox'
export * from './ui/command'
export * from './ui/data-table'
export * from './ui/date-picker'
export * from './ui/date-range-picker'
export * from './ui/dialog'
export * from './ui/dropdown-menu'
export * from './ui/empty'
export * from './ui/field'
export * from './ui/input'
export * from './ui/input-group'
export * from './ui/label'
export * from './ui/pagination'
export * from './ui/popover'
export * from './ui/radio-group'
export * from './ui/rich-text-editor'
export * from './ui/select'
export * from './ui/separator'
export * from './ui/sheet'
export * from './ui/sidebar'
export * from './ui/skeleton'
export * from './ui/slot'
export * from './ui/sonner'
export * from './ui/switch'
export * from './ui/textarea'
export * from './ui/tooltip'
