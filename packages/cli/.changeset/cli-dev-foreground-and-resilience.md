---
"@spree/cli": minor
---

`spree dev` now runs the app in the foreground like every other dev server (`vite dev`, `bin/dev`): it streams web + worker logs and `Ctrl+C` stops them, while the database containers keep running for a fast next boot — `spree stop` remains the full shutdown. Previously `Ctrl+C` only detached from the logs and left everything running. Real compose failures (daemon down, port conflict, bad config) now exit with the underlying code instead of printing a clean shutdown message; a `Ctrl+C` stop still ends cleanly.

Add `spree restart` — restarts `web` + `worker` in place (same image, same volumes, fresh Rails process). For `config/initializers` changes and anything Zeitwerk doesn't reload; it does not pick up Gemfile or compose changes.

`spree bundle` now works when the stack is down: if the `web` container isn't running — for example after a `Gemfile.lock` change crash-loops the boot, which is exactly when bundler is needed — it runs bundler in a one-off container against the same `bundle_cache` volume instead of failing on `exec`.

`spree dev` and `spree build` detect monorepo edge projects (`SPREE_PATH` in `.env`) and refuse with a pointer to the matching `pnpm server:*` script, instead of materializing the wrong compose config against the running edge stack.

`spree migrate` prints a header for each step and a completion note — previously a fully up-to-date run produced no output at all, leaving no signal that anything ran.

`spree upgrade`'s closing "Next steps" panel now includes the SDK side of the upgrade: when the project has the conventional `apps/storefront` consuming `@spree/sdk`, it names the currently-declared version and reminds you to bump it to the release matching the new Spree version.
