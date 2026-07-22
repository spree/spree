---
"@spree/cli": patch
---

All app-facing commands now fall back to a one-off container (`docker compose run --rm`) when the web container is not running, instead of failing on `docker compose exec`. Previously only `spree bundle`, `spree console`, `spree shell`, and `spree rspec` did this; the same behavior now covers `spree migrate` (+ `migrate:rollback`, `migrate:status`), `spree rails`, `spree rake`, `spree task`, `spree exec`, `spree routes`, `spree generate`, `spree seed`, `spree sample-data`, `spree user`, `spree api-key`, and `spree upgrade` — which no longer refuses to run while the stack is down. The one-off container cold-starts and health-waits postgres, so these commands work from a fully stopped stack. On the fallback path `spree migrate` collapses its two steps into a single invocation, paying the one-off container's cold Rails boot once.
