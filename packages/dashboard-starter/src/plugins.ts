// Dashboard customizations for this store.
//
// Register nav entries, routes, slot widgets, and table columns against the
// shared registries — the same API distributed plugins use. Imported once
// from main.tsx, before the dashboard renders.
//
// Example:
//
//   import { defineDashboardPlugin } from '@spree/dashboard'
//   import { AnalyticsPage } from './pages/analytics'
//
//   defineDashboardPlugin({
//     nav: [{ key: 'analytics', label: 'Analytics', path: '/analytics', position: 60 }],
//     routes: [{ key: 'analytics', path: '/analytics', component: AnalyticsPage }],
//   })
//
// Building custom pages? Add the framework and design-system packages first —
// `pnpm add @spree/dashboard-core @spree/dashboard-ui` — then import hooks,
// providers, and UI primitives from those.
//
// Docs: https://spreecommerce.org/docs/developer/dashboard/customization/quickstart

export {}
