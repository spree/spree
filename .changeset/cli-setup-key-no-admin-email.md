---
"@spree/cli": patch
---

The read-only API key the CLI creates for itself while setting up a project no longer emails the store's admins about a new Admin API key. Keys created with `spree api-key create` still do.
