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
API, so they keep their own versions and release on their own tags.

## Releasing

Every release is published by `.github/workflows/release.yml` from a tag
pushed on a commit already on `main`. The workflow checks the tag against the
versions in the repository first, and skips any version already published, so
a failed release can be re-run.

| Tag | Publishes |
| --- | --- |
| `v6.0.0.rc7` | the Spree gems and the packages in the group |
| `@spree/cli@3.5.0` | `@spree/cli` |
| `create-spree-app@2.4.1` | `create-spree-app` |

**A Spree release:**

1. Bump `Spree::VERSION` in `spree/core/lib/spree/core/version.rb`.
2. Run `pnpm version:packages`. It runs `changeset version`, then moves every
   package in the group to the Spree version. A package with no changes still
   gets the new version and a changelog entry saying so. Pending changesets
   for the tools are versioned too.
3. Merge, then push the Spree tag, plus a tag for each tool whose version
   changed: `git push origin v6.0.0.rc7 @spree/cli@3.5.0`.

**A tool release between Spree releases:** run `pnpm version:tools`, which
versions only the tools and leaves the group's changesets for the next Spree
release. Merge, then push the tool's tag.

GitHub starts no workflow for tags pushed more than three at a time, so push
at most three tags at once.

Never run plain `changeset version` for a release: it would give the group a
version computed from the changesets. For packages in the group, the bump type
a changeset names only decides which heading its changelog entry goes under.

`--ignore` defers changesets, it doesn't discard them.

## Peer ranges between workspace packages

Never use `workspace:^` for a peerDependency on another workspace package
(e.g. dashboard-core → dashboard-ui). Changesets majors a peer-dependent
whenever its peer's new version escapes the declared range, and that cascades
through the fixed group. Use a literal range instead, paired with
`onlyUpdatePeerDependentsWhenOutOfRange` in `config.json`.
`pnpm version:packages` sets those ranges on every release to that release and
anything after it in the same major (`>=6.0.1-rc.1 <7.0.0-0`); starting the range
at the full version is what lets a patch release candidate satisfy it.

Docs: https://github.com/changesets/changesets
