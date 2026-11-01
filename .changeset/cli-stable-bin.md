---
"@spree/cli": patch
---

The `spree` command now starts from `bin/spree.js`, which loads the built `dist/index.js`. Nothing changes for installed copies. In the Spree monorepo, `pnpm install` now builds the CLI and links the `spree` command on a fresh clone, without the "Failed to create bin" warning.
