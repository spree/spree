---
"@spree/seller-dashboard": patch
---

Pages registered with `defineDashboardPlugin({ routes })` now open in the seller panel. Until now the panel had nowhere to render them, so a nav entry pointing at a custom page led to a "not found" screen. Unknown paths and pages the seller lacks permission for show a message inside the panel, and a page that fails to render no longer takes the panel down with it.
