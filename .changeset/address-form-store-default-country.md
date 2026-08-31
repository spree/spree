---
"@spree/dashboard-core": patch
"@spree/admin-sdk": patch
---

New address forms pre-select the store's default country.

The Admin store payload now includes `default_country_code` (the same country the default market already answers). The shared address dialog uses it for new records and leaves an existing address's country alone.
