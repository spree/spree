---
'@spree/admin-sdk': major
'@spree/sdk': major
---

Rename the geography fields to `country_code` and `state_code` across the v3 API, replacing `country_iso` and `state_abbr`. Addresses, stock locations, delivery zone members, markets, tax rates and tax exemption certificates all use the new names, on read and on write. Markets rename their list of countries from `country_isos` to `country_codes`.

Addresses keep `country_iso` and `state_abbr` as deprecated read fields and accepted write names for one release, so existing storefronts keep working; both are removed in 6.1. Every other resource moves outright.
