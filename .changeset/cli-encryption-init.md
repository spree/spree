---
"@spree/cli": minor
---

New `spree encryption init` command adds Active Record encryption keys (`ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `_DETERMINISTIC_KEY`, `_KEY_DERIVATION_SALT`) to an existing project's `.env`, so Spree encrypts webhook signing secrets, payment gateway customer IDs and OAuth tokens at rest instead of storing them in plain text. It never overwrites keys that are already set. `spree encryption init --print` only prints a fresh set, for your production host.
