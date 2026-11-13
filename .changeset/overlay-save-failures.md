---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Add discount, Add fee, Add payment, Split fulfillment and a customer group's Add member report a failed save instead of staying open without a word. A stock location's on-hand row and a company's Add member dialog show a rejected value under its field. `toastMutationError` in `@spree/dashboard-core` toasts a failed write in the words a form would show.
