---
"@spree/dashboard-core": patch
---

Moved the money, percentage, typed-amount and display-name helpers into `@spree/core`, which the dashboard packages now depend on. `@spree/dashboard-core` still exports them under the same names.
