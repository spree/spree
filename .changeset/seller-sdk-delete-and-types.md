---
"@spree/seller-sdk": minor
"@spree/admin-sdk": minor
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Methods that delete a record are named `delete` in both SDKs. In the Seller SDK, `taxIdentifiers.remove`, `team.remove` and `invitations.revoke` are now `taxIdentifiers.delete`, `team.delete` and `invitations.delete`. In the Admin SDK, `sellers.team.remove` and `sellers.invitations.remove` are now `sellers.team.delete` and `sellers.invitations.delete`. Methods that detach something from a cart or order (`remove`), or change a record without deleting it (`revoke`), keep their names.

Seller SDK types are corrected: `team.invite` returns the `Invitation`, `auth.providers` returns `AuthProvidersResponse`, and `SellerTaxIdentifierParams` is split into `SellerTaxIdentifierCreateParams`, which requires `kind` and `value`, and `SellerTaxIdentifierUpdateParams`.
