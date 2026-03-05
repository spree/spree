---
"@spree/sdk": patch
---

Made `publishableKey` optional in client config. Admin-only consumers no longer need to provide a publishable key. At least one of `publishableKey` or `secretKey` must still be provided.
