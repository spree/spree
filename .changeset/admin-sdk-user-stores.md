---
"@spree/admin-sdk": patch
---

`AdminUser` now includes a `stores` array — every store the user holds a role on (`{ id, name, code }` with prefixed IDs), powering the dashboard store switcher.
