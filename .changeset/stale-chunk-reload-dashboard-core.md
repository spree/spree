---
"@spree/dashboard-core": patch
---

A tab left open across a deploy reloads onto the new build the first time it needs a code-split chunk the deploy removed, instead of crashing the page into "Failed to fetch dynamically imported module". `installStaleChunkRecovery()` listens for Vite's `vite:preloadError`, and `reportCaughtError` reloads for such an error rather than reporting it. A chunk still missing within a minute of that reload is a broken build: it reaches the error screen and error tracking as before, so the page never reloads in a loop.
