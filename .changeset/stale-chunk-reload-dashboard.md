---
"@spree/dashboard": patch
---

The admin dashboard reloads a tab left open across a deploy onto the new build when it asks for a chunk the deploy removed, instead of crashing the page. Hosts that spell out `<Dashboard>`'s provider stack get this too: it runs when `@spree/dashboard` is imported.
