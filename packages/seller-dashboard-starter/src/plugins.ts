// Seller panel customisations for this marketplace.
//
// The seller panel is the part of a marketplace most often shaped to fit —
// but shaping it should mean adding and removing, not rewriting. Register
// nav entries, slot widgets and table columns against the shared registries
// here, the same API distributed plugins use. Imported once from main.tsx,
// before the panel renders.
//
// Keep this file a map of what you added: the registrations live here, the
// implementations live in slots/, pages/, hooks/, tables/ and schemas/ — one file per
// resource, the same layout the seller panel uses internally. Translations go
// in locales/ and merge in with `i18n.addResourceBundle`.
//
// Example — add a card to the team screen and drop the built-in team entry
// from the navigation (the seller panel does not support new pages yet):
//
//   import { defineDashboardPlugin } from '@spree/seller-dashboard'
//   import { TeamAuditCard } from './slots/team-audit-card'
//
//   defineDashboardPlugin({
//     nav: { remove: ['team'] },
//     slots: {
//       'seller.team.after': [{ id: 'audit', component: TeamAuditCard }],
//     },
//   })
//
// Slots the built-in screens expose: `seller.team.actions`, `seller.team.after`,
// `seller.product.form_main`, `seller.product.form_sidebar`,
// `seller.product.media.form_fields`, `seller.product.media.actions`,
// `seller.product.variant.form_fields`, `seller.order.form_sidebar`,
// `seller.payout.form_sidebar`, `seller.profile.form_main`,
// `seller.profile.form_sidebar`.
//
// `@spree/dashboard-core` and `@spree/dashboard-ui` are already installed —
// import hooks, providers and UI primitives straight from them.

export {}
