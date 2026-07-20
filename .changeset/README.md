# Changesets

One workspace-wide Changesets instance — add changesets here (`pnpm changeset`
from the repo root), never in per-package `.changeset/` directories.

The dashboard packages (`@spree/dashboard`, `@spree/dashboard-core`,
`@spree/dashboard-ui`) are a `fixed` group: they version and release together
under one version number, so a scaffolded app always installs a trio that was
released as a set. `@spree/admin-sdk` versions independently — it's a
standalone API client, not part of the dashboard release train.

## Release trains

`@spree/sdk` is a stable 1.x package whose releases track Spree releases;
everything else (dashboard trio, admin-sdk, cli, create-spree-app) is the
Developer Preview train releasing continuously. The two run on different
schedules, so:

- **Preview release** (the frequent one): `pnpm version:preview` — versions
  everything pending except `@spree/sdk`, whose changesets stay queued.
- **SDK release** (with a Spree release): plain `pnpm exec changeset version`.
  The preview queues drain continuously, so on SDK release day they're
  usually empty; if something preview-side is pending and shouldn't ship,
  hold it back with additional `--ignore` flags.

Held-back changesets are preserved, not deleted — `--ignore` defers, it
doesn't discard.

## Peer ranges between workspace packages

Never use `workspace:^` for a peerDependency on another workspace package
(e.g. dashboard-core → dashboard-ui). Changesets majors a peer-dependent
whenever its peer's new version escapes the declared range, and on 0.x a
caret range escapes on every minor — inside the fixed group that cascades a
routine minor release into 1.0.0. Use wide literal ranges instead
(`>=0.10.0 <2`), paired with `onlyUpdatePeerDependentsWhenOutOfRange` in
`config.json`.

Docs: https://github.com/changesets/changesets
