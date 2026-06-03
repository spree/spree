---
"@spree/cli": minor
---

Add `spree generate`, `spree migrate` (+ `migrate:rollback`, `migrate:status`), `spree build`, `spree db:reset`, `spree db:console`, and `spree routes`. `spree generate` auto-prefixes `spree:` so `spree generate model Brand name:string` invokes the Spree generator. `spree db:reset` and `spree build --reset-bundle` are destructive and prompt by default; pass `--yes` to skip the prompt in CI. `spree build` targets `docker-compose.dev.yml` explicitly when present so it works before `spree eject`.

`spree eject` no longer runs a separate `docker compose build` step (the dev compose builds on first `up -d` automatically). Its description and post-eject hints now point at `spree bundle add` for gems and `spree build` for Dockerfile / `.ruby-version` changes.
