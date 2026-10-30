---
"@spree/dashboard-ui": patch
"@spree/dashboard-core": patch
"@spree/dashboard": patch
---

The command palette is now built on Base UI's Autocomplete instead of `cmdk`, so the dashboard no longer installs `cmdk` or any Radix packages. It looks and works the same: arrow keys move the highlight, Enter opens the highlighted row and Escape closes the palette. The `Command` components in `@spree/dashboard-ui` keep their props, so plugins that use them need no changes.
