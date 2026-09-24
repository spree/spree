// Dashboard customizations for this store.
//
// Register nav entries, routes, slot widgets, and table columns against the
// shared registries — the same API distributed plugins use. Imported once
// from main.tsx, before the dashboard renders.
//
// Keep this file a map of what you added: the registrations live here, the
// implementations live in pages/, hooks/, tables/ and schemas/. See the
// README for what belongs where.
//
// Example:
//
//   import { defineDashboardPlugin } from '@spree/dashboard'
//   import { AnalyticsPage } from './pages/analytics'
//
//   defineDashboardPlugin({
//     nav: [{
//       key: 'analytics',
//       label: i18n.t('admin.analytics.nav'),
//       path: '/analytics',
//       position: 650,
//     }],
//     routes: [{ key: 'analytics', path: '/analytics', component: AnalyticsPage }],
//   })
//
// Docs: https://spreecommerce.org/docs/developer/dashboard/customization/quickstart

import { i18n } from '@spree/dashboard'
import en from './locales/en.json'

// Merges your `admin.*` keys into the dashboard's namespace without dropping
// its own. Add a bundle per locale you ship.
i18n.addResourceBundle('en', 'translation', en, true, true)
