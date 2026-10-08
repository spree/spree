---
"@spree/cli": patch
---

`spree upgrade` now updates the `@spree/*` packages right after the server (gems or image) and before migrations and data backfills, so a failing migration or backfill no longer leaves the dashboard packages on the previous release.
