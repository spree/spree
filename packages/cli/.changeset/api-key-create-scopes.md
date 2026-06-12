---
"@spree/cli": minor
---

`spree api-key create` now supports scopes for secret keys via `--scopes` (comma-separated, e.g. `--scopes read_orders,write_products`) or an interactive prompt defaulting to `read_all`. Required against Spree 5.5+ servers, where secret keys must carry at least one scope.
