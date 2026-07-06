# Render deployment notes

This fork deploys the Rails backend on Render from a generated `server` app based on `spree/spree-starter`.

The important deployment invariant is that Render must use this repository's local Spree gems, not only the public RubyGems releases. The build and runtime both rely on `SPREE_PATH` for that.

## Confirmed working setup

The current Render setup was confirmed working after a Bundler failure involving the local Spree core gem.

Keep these parts together:

- the build creates a fresh generated starter app for each deploy attempt;
- the generated starter app receives a `.env` file with `SPREE_PATH` before Bundler resolves dependencies;
- `render.yaml` also exposes `SPREE_PATH` at runtime;
- Bundler is run in an isolated, non-frozen context so stale Render cache does not point it at the wrong gem source.

## Maintenance warning

Be careful when changing `bin/render-build.sh` or `render.yaml`. Removing the `SPREE_PATH` setup or reusing a stale generated `server` directory can make Render resolve the wrong Spree gems and break deployment again.
