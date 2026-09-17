---
'@spree/cli': patch
---

`spree init` says where sample data comes from. A run that seeds no admin (no `--admin-email`) cannot load sample data, since its imports need an owner, so init now points at the setup screen's own "Load sample data" option instead of skipping silently. The `--admin-email` and `--no-sample-data` help text says which flags belong to scripted installs.
