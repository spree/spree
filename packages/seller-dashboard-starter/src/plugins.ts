// Seller panel customisations for this marketplace.
//
// The seller panel is the part of a marketplace most often shaped to fit —
// but shaping it should mean adding and removing, not rewriting. Register
// nav entries, slot widgets and table columns against the shared registries
// here, the same API distributed plugins use. Imported once from main.tsx,
// before the panel renders.
//
// Example — add a payouts page and drop the built-in team screen:
//
//   import { defineDashboardPlugin } from '@spree/seller-dashboard'
//   import { PayoutsPage } from './pages/payouts'
//
//   defineDashboardPlugin({
//     nav: {
//       add: [{ key: 'payouts', label: 'Payouts', path: '/payouts', position: 300 }],
//       remove: ['team'],
//     },
//     slots: {
//       'seller.team.after': [{ id: 'audit', component: TeamAuditCard }],
//     },
//   })
//
// Slots the built-in screens expose: `seller.team.actions`, `seller.team.after`.
//
// Building custom pages? Add the framework and design-system packages first —
// `pnpm add @spree/dashboard-core @spree/dashboard-ui` — then import hooks,
// providers, and UI primitives from those.

export {}
