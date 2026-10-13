---
"@spree/dashboard": patch
"@spree/admin-sdk": patch
---

Removed the `display_*` money fields from the `Email*` types and Zod schemas; templates format amounts with the `money` filter. Added `EmailCustomer`, `EmailCustomerGroup` and `EmailNewsletterSubscriber`, which the password reset email's `customer` variable now uses.
