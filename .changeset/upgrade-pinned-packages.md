---
"@spree/cli": patch
---

`spree upgrade` now moves `@spree/*` packages pinned to an exact version to the newest release of the same major and keeps them pinned. Before, it left them on the old release while the server moved on. It then dedupes the dependency tree, so a dependency the new release pins doesn't end up installed twice and break type checks.
