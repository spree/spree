---
'create-spree-app': minor
---

Pick free host ports for Postgres and Meilisearch at scaffold time (walking up from the 5433/7700 defaults) and write them to the project `.env` as `SPREE_DB_PORT` / `SPREE_MEILISEARCH_PORT`, so projects scaffolded next to a running Spree stack never fight over host ports.
