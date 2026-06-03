---
"@spree/cli": minor
---

Add `spree upgrade` — sequencer around the dev upgrade flow. Runs `bundle update`, applies pending migrations, then delegates to `bin/rake spree:upgrade` (which executes the version-specific data backfills from a manifest shipped inside `spree_core`). On production, only the rake task runs — your deploy pipeline handles `bundle install` and `db:migrate`. Flags `--plan`, `--step <id>`, `--to <version>`, `--yes` map to env vars (`DRY_RUN`, `STEP`, `TO`) on the rake task so the same arguments work on both surfaces.
