---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
---

The login page's `login.after` slot now receives the last failed password sign-in: `error` (the API's error, with its `code` and `status`) and the `email` it was submitted with. Plugins can offer a next step for a specific failure, such as resending a confirmation email. Import the name as `LOGIN_AFTER_SLOT` and the context as `LoginAfterSlotContext` from `@spree/dashboard-core`.
