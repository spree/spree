---
"@spree/cli": minor
"create-spree-app": patch
---

Renamed the CLI commands and flags that were named after Rails tools, so each command describes what it does rather than which Rails tool runs it. `spree test` replaces `spree rspec`, `spree add <extension>` replaces `spree bundle add`, `spree migrate:rollback --steps n` replaces `STEP=n`, `spree build --reset-deps` replaces `--reset-bundle`, and `spree plugin new` takes `--backend-name` / `--no-backend`. `spree rails`, `spree rake`, `spree bundle`, `spree routes`, `spree rspec` and the old flags still work and print a notice naming the replacement; they will be removed in Spree 7.0. Also fixed the setup-link hint `spree init` printed, which named a command that does not exist.
