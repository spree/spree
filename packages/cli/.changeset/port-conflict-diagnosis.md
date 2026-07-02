---
'@spree/cli': minor
---

Explain port conflicts instead of dumping raw compose output: when `spree dev`, `spree init`, or `spree eject` fail to boot the stack, the CLI now names the taken host port, who is holding it (another compose project's warm databases, a stray container, or a non-Docker process), and both remedies — `spree stop` in the other project, or a `SPREE_PORT` / `SPREE_DB_PORT` / `SPREE_MEILISEARCH_PORT` override in `.env` to run projects side by side (the override hint is only offered when the project's compose file actually interpolates that variable). `spree db:reset` now reports the configured `SPREE_DB_PORT` instead of a hardcoded 5433.
