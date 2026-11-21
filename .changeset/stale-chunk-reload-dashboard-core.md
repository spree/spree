---
"@spree/dashboard-core": patch
---

A tab left open across a deploy reloads onto the new build the first time it needs a code-split chunk the deploy removed, instead of crashing the page into "Failed to fetch dynamically imported module". `installStaleChunkRecovery()` listens for Vite's `vite:preloadError`, and `reportCaughtError` reloads for such an error rather than reporting it. A chunk still missing within a minute of that reload is a broken build: it reaches error tracking as before, so the page never reloads in a loop.

New `IsolatedLazy` loads a component that is not the page itself, such as a drawer, so that a failed load costs only that component: the page keeps rendering with any unsaved edits, and the next `retryKey` loads it again. The "View as JSON" drawer and the developer inspector use it, so a failed load of either no longer replaces the page (or, for the inspector, the whole panel) with an error screen.
