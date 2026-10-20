---
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

Moved the money, percentage, typed-amount, display-name and code-shape helpers and the list of currencies still in use into `@spree/core`, which the dashboard packages and the seller panel now depend on. `@spree/dashboard-core` still exports them under the same names.

- A customer's average order value is now worked out exactly.
- Calculator summaries show money with each currency's own number of decimals.
- The bulk variant editor now reads `1,500` as fifteen hundred and `1,234.5` correctly when you type or paste a weight or dimension.
