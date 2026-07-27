// @spree/dashboard — the Spree admin app shell.
//
// Hosts import the shell component and a router built from their own
// generated route tree (see `@spree/dashboard/vite` for the generation):
//
//     import { createDashboardRouter, Dashboard } from '@spree/dashboard'

// Plugin facade re-export — lets a host register in-app customizations
// (nav entries, routes, slot widgets) without declaring @spree/dashboard-core
// as a direct dependency. Distributed plugins keep importing from
// `@spree/dashboard-core/plugin`.
export * from '@spree/dashboard-core/plugin'
export { createDashboardRouter } from './create-router'
export { Dashboard } from './dashboard'
