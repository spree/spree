---
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
---

Apps no longer choose the versions of `@tanstack/react-table`, `@tanstack/react-hotkeys` and `@hookform/resolvers` used inside the dashboard packages: they are now regular dependencies, so upgrading them in an app (for example to React Table 9) no longer breaks type checking or the dashboard itself. Table column definitions are available as `DataGridColumn` from `@spree/dashboard-ui`. The TipTap menu extensions are pinned to the same version as the rest of the editor.
