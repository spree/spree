---
"create-spree-app": minor
---

New projects get Active Record encryption keys: the generated `.env` now includes `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`, so webhook signing secrets, payment gateway customer IDs and OAuth tokens are encrypted at rest out of the box instead of being stored in plain text.
