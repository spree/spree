---
'@spree/admin-sdk': minor
---

Add provider-dispatched login. `client.auth.login()` now accepts third-party identity-provider payloads (e.g. `{ provider: 'okta', token: '<jwt>' }`) in addition to the existing `{ email, password }` shape — `LoginCredentials` is now a discriminated union of `EmailPasswordLogin | ProviderLogin`, both newly exported. Pairs with the server-side strategy registry at `Spree.admin_authentication_strategies`. Existing email/password calls are unchanged.
