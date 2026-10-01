---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

Pages in a host app's own `src/routes/` directory are now compiled into the route tree of both the admin dashboard and the seller panel, so links to them are type-checked like links to built-in pages. Packaged plugins can now ship seller panel pages by declaring a `sellerRoutes` directory in their `spree.dashboard` marker, next to the existing `routes` directory for the admin dashboard. The route clash check moved to `@spree/dashboard-core/vite/route-collisions`; the old `@spree/dashboard/vite/route-collisions` path still works. An app that keeps something other than route files in `src/routes/` should pass `routes: false` (or another directory) to the Vite plugin.
