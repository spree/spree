---
"@spree/cli": patch
---

Fixed `spree eject` failing on a fresh stack with `service "web" is not running`. The development database is now created before the app server starts, since the server exits when that database is missing; `spree init` on an ejected project does the same. Eject also switches older dev compose files to a Postgres health check that only passes once the database server is really up.
