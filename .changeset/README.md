# Changesets

One workspace-wide Changesets instance — add changesets here (`pnpm changeset`
from the repo root), never in per-package `.changeset/` directories.

## Packages released with Spree

The packages that talk to the Spree API — `@spree/sdk`, `@spree/admin-sdk`,
`@spree/seller-sdk`, `@spree/core`, `@spree/dashboard`,
`@spree/dashboard-core`, `@spree/dashboard-ui` and `@spree/seller-dashboard` —
are one `fixed` group and carry the version of the Spree gems, in npm's
spelling: gems `6.0.0.rc7` ship as `6.0.0-rc.7`, gems `6.0.2` as `6.0.2`. A
bug report naming `@spree/sdk@6.0.2` therefore names the backend too.

`@spree/cli` and `create-spree-app` manage projects rather than talk to the
API, so they keep their own versions and release whenever they change.

## Releasing

1. Bump `Spree::VERSION` in `spree/core/lib/spree/core/version.rb`.
2. Run `pnpm version:packages`. It runs `changeset version`, then moves every
   package in the group to the Spree version. A package with no changes still
   gets the new version and a changelog entry saying so.

Never run plain `changeset version` for a release: it would give the group a
version computed from the changesets. For packages in the group, the bump type
a changeset names only decides which heading its changelog entry goes under.

`--ignore` defers changesets, it doesn't discard them.

## Peer ranges between workspace packages

Never use `workspace:^` for a peerDependency on another workspace package
(e.g. dashboard-core → dashboard-ui). Changesets majors a peer-dependent
whenever its peer's new version escapes the declared range, and that cascades
through the fixed group. Use a literal range covering the whole major
(`>=6.0.0-0 <7.0.0-0`) instead, paired with
`onlyUpdatePeerDependentsWhenOutOfRange` in `config.json`;
`pnpm version:packages` moves those ranges to the new major on a major release.

Docs: https://github.com/changesets/changesets
