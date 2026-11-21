---
"@spree/dashboard": patch
---

The admin dashboard reloads a tab left open across a deploy onto the new build when it asks for a chunk the deploy removed, instead of crashing the page. Hosts that spell out `<Dashboard>`'s provider stack get this too: it runs when `@spree/dashboard` is imported. On a webhook endpoint's page, a delivery payload viewer that fails to load no longer replaces the page with an error screen.
