---
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
---

Projects that install the dashboard packages from npm now get a single copy of the rich text editor library. `@spree/dashboard` no longer declares its own, looser TipTap ranges next to the exact versions in `@spree/dashboard-ui`, so a newer TipTap release can no longer install beside the pinned one and break type checking.
