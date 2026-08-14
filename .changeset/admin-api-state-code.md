---
'@spree/admin-sdk': minor
---

Rename `state_abbr` to `state_code` across the Admin API: address, stock location and delivery zone member payloads now serialize `state_code`, and write endpoints accept `state_code` instead of `state_abbr`. The canonical name matches the tax jurisdiction fields (`country_iso`/`state_code`); the Store API contract is unchanged and keeps `state_abbr`.
