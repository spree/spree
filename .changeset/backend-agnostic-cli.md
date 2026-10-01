---
"@spree/cli": minor
"create-spree-app": patch
---

Renamed the CLI commands and flags that were named after Rails tools, so the same commands keep working when Spree 7 moves the backend to Node. `spree test` replaces `spree rspec`, `spree add <extension>` installs an extension and runs its installer, `spree migrate:rollback --steps n` replaces `STEP=n`, `spree build --reset-deps` replaces `--reset-bundle`, and `spree plugin new` takes `--backend-name` / `--no-backend`. `spree rails`, `spree rake`, `spree bundle`, `spree routes`, `spree rspec`, the old flags and every generator except `api_resource` still work and print a notice naming the replacement; they are removed in Spree 7. Also fixed the setup-link hint `spree init` printed, which named a command that does not exist.
