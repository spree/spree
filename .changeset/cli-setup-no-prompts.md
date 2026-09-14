---
'@spree/cli': major
---

`spree init` no longer prompts for an admin account.

The setup screen creates the first admin, asks where the store trades, and offers to load sample data, so `spree init` prints the one-time setup link instead of asking the same questions in the terminal. `--admin-email` and `--admin-password` remain for scripted installs, where `--no-sample-data` still applies; a run without them loads no sample data and says how to load it later.
