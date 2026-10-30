---
"@spree/dashboard-ui": patch
"@spree/dashboard-core": patch
"@spree/dashboard": patch
---

The command palette is now built on Base UI's Autocomplete instead of `cmdk`, so the dashboard no longer installs `cmdk` or any Radix packages. It looks and works the same: arrow keys move the highlight, Enter opens the highlighted row and Escape closes the palette. For plugins that use the `Command` components from `@spree/dashboard-ui`: the query now goes on `<Command value onValueChange>` instead of `<CommandInput>`, `shouldFilter` is gone because rows are never filtered for you, and `<CommandEmpty>` shows whenever it is rendered.
