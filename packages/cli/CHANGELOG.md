# @spree/cli

## 2.0.0

### Major Release

Stable release of `@spree/cli` for Spree Commerce 5.4.0. Docker-based project management CLI with `spree init`, `spree start`, `spree stop`, `spree eject`, and `spree update` commands.

## 2.0.0-beta.7

### Patch Changes

- Run `spree:search:reindex` during `spree init` after sample data is loaded. This initializes the Meilisearch search index so product search works immediately after setup.

## 2.0.0-beta.6

### Minor Changes

- Add `spree eject` command to switch from prebuilt Docker image to building from local `backend/` directory. Also update port detection to read `SPREE_PORT` from `.env`.

## 2.0.0-beta.5

### Patch Changes

- Automatically update storefront `.env.local` with the real API key during `spree init`

## 2.0.0-beta.4

### Patch Changes

- Pull latest Docker image during `spree init` to ensure fresh setups always use the newest version
- Show Docker pull progress output during `spree init` and `spree update` instead of a spinner
