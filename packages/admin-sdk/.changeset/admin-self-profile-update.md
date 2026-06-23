---
"@spree/admin-sdk": minor
---

Add self-service profile updates for the authenticated admin. `client.me.update(params)` (`PATCH /me`) lets the signed-in admin change their own `selected_locale` (admin UI display language), `first_name`, and `last_name` without going through the store-scoped staff-management endpoint. The `MeResponse.user` shape now includes `selected_locale`, and a new `MeUpdateParams` type describes the writable fields.
