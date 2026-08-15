---
'@spree/admin-sdk': major
---

First-run setup asks which country the store sells from.

`completeSetup` now requires `country_code` and accepts optional `locale` and `currency`. Both default to the country's own — its first official language and its currency — so a store's money and geography agree unless you say otherwise. An unrecognised currency is now rejected rather than quietly ignored.

`login`, `acceptInvitation`, `resetPassword` and `completeSetup` on the dashboard auth context now resolve with the session they establish, so callers can read the signed-in user without waiting for provider state.

A new `auth.setupCountries()` lists the countries a store can be set up in, each with the currency and official languages derived from it. Like the rest of the setup flow it needs no credentials, and stops answering once an admin account exists.
