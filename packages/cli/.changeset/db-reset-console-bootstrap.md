---
"@spree/cli": patch
---

Fix `spree db:reset` and `spree console` when the stack is down or already serving. `db:reset` now self-heals from any state: it stops the web + worker containers holding open Postgres connections (which a plain `DROP DATABASE` rejects), then runs the drop/create/migrate/seed chain in a one-off `docker compose run --rm web` container whose dependencies cold-start automatically — so a reset works whether the stack is up, partially up, or fully stopped, and a stale host DB client (TablePlus/psql on port 5433) blocking the drop now produces an actionable hint instead of a raw error. `spree console` falls back to a one-off container when web is down (mirroring `spree bundle`) instead of failing, and `spree db:console` guides you to start the stack when Postgres isn't running. Both new fallbacks refuse cleanly in monorepo edge projects, consistent with the other commands.
