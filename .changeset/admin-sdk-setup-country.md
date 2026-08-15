---
'@spree/admin-sdk': major
---

First-run setup asks which country the store sells from.

`completeSetup` now requires `country_code` and accepts an optional `locale`. The `currency` parameter is gone — the currency follows from the country, so passing one was a way to end up with a store whose money and geography disagreed.

A new `auth.setupCountries()` lists the countries a store can be set up in, each with the currency and official languages derived from it. Like the rest of the setup flow it needs no credentials, and stops answering once an admin account exists.
