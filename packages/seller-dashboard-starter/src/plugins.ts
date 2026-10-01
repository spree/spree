// Seller panel customisations for this marketplace.
//
// The seller panel is the part of a marketplace most often shaped to fit —
// but shaping it should mean adding and removing, not rewriting. Register
// nav entries, slot widgets and table columns against the shared registries
// here, the same API distributed plugins use. Imported once from main.tsx,
// before the panel renders.
//
// Keep this file a map of what you added: the registrations live here, the
// implementations live in pages/, hooks/, tables/ and schemas/ — one file per
// resource, the same layout the seller panel uses internally. Translations go
// in locales/ and merge in with `i18n.addResourceBundle`.
//
// Example — add a reviews page and drop the built-in team screen. A page
// needs both a `routes` entry and a nav entry with the same path. (Or make the
// page a route file in src/routes/, compiled into the typed route tree so
// links to it are checked — then only the nav entry goes here.)
//
//   import { defineDashboardPlugin } from '@spree/seller-dashboard'
//   import { ReviewsPage } from './pages/reviews'
//
//   defineDashboardPlugin({
//     routes: [{ key: 'reviews', path: '/reviews', component: ReviewsPage }],
//     nav: {
//       add: [{ key: 'reviews', label: 'Reviews', path: '/reviews', position: 300 }],
//       remove: ['team'],
//     },
//     slots: {
//       'seller.team.after': [{ id: 'audit', component: TeamAuditCard }],
//     },
//   })
//
// Slots the built-in screens expose: `seller.team.actions`, `seller.team.after`.
//
// `@spree/dashboard-core` and `@spree/dashboard-ui` are already installed —
// import hooks, providers and UI primitives straight from them.

export {}
