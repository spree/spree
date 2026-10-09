---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
---

Plugins and host apps can now add pages outside a store, such as onboarding, sign-up and account pages. File routes go in the new `authenticatedRoutes` (signed-in users) or `publicRoutes` (anyone) directories of a plugin's `spree.dashboard` marker; registry routes take `scope: 'authenticated'` or `scope: 'public'` with a full URL path. Both mount at the root, outside the store layout, and a page that takes the path of a built-in page fails with an error naming it.

The signed-in landing page at `/` can be replaced through the new `store_selection` slot, for example with a list of stores and a way to create one, and the login page renders extra content, such as a sign-up link, from the new `login.after` slot.
