---
'@spree/admin-sdk': major
'@spree/sdk': major
---

Rename `state_abbr` to `state_code` across the v3 API. Addresses, stock locations and delivery zone members now serialize `state_code`, and write endpoints accept it — the canonical name matches the tax jurisdiction fields (`country_iso`/`state_code`).

Addresses keep `state_abbr` as a deprecated read field and an accepted write name for one release, so existing storefronts keep working; it is removed in 6.1. Every other resource moves outright.
