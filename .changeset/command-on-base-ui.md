---
"@spree/dashboard-ui": patch
"@spree/dashboard-core": patch
"@spree/dashboard": patch
---

The command palette is now built on Base UI's Autocomplete instead of `cmdk`, so the dashboard no longer installs `cmdk` or any Radix packages. It looks and works the same: arrow keys move the highlight, Enter opens the highlighted row and Escape closes the palette. The `Command` components in `@spree/dashboard-ui` keep the props the dashboard uses: `shouldFilter` on `Command`, `value` and `onValueChange` on `CommandInput`, `value`, `keywords` and `onSelect` on `CommandItem`, and `heading` on `CommandGroup`. The `cmdk` options on `Command` for the highlighted row (`value`, `onValueChange`), custom matching (`filter`) and wrap-around (`loop`) are no longer available.
