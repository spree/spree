---
"@spree/cli": patch
---

`spree upgrade` now raises an admin app's own ranges for the libraries the Spree packages take as peer dependencies, such as React Hook Form, i18next and the TanStack libraries, when they start below what the new release requires. It installs them in the same step as the Spree packages and lists each change. Before, an app could keep an older copy: npm refused the install, and pnpm installed it with a warning while the dashboard ran against a version it was not built for.
