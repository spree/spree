---
"@spree/dashboard-core": patch
---

The top-bar "View store" link is now only shown when the store has a storefront URL configured (`preferred_storefront_url`), and the sidebar store switcher is a real switcher: it lists every store the signed-in admin can access and navigates between store dashboards, rendering a plain header (no dropdown) for single-store admins. The switcher trigger also gains a localized accessible name.
