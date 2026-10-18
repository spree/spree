---
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Apps no longer choose the versions of `@tanstack/react-table`, `@tanstack/react-hotkeys` and `@hookform/resolvers` used inside the dashboard packages: they are now regular dependencies, so upgrading them in an app (for example to React Table 9) no longer breaks type checking or the dashboard itself. Table column definitions are available as `DataGridColumn` from `@spree/dashboard-ui`. The TipTap menu extensions are pinned to the same version as the rest of the editor.

`@spree/dashboard` and `@spree/seller-dashboard` now list the libraries they share with the app (React, TanStack Router and Query, React Hook Form, i18next, react-i18next and the Spree dashboard packages) as peer dependencies, so the app's copy is the only one. Before, an app on a different version got a second copy, which crashes React or makes plugins disappear. Apps must list these packages as their own dependencies; the starter templates now include React Hook Form, i18next and react-i18next.
