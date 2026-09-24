---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
---

Fixed the dashboard failing to start in newly created projects.

Since 1.0.0-beta.4, a fresh project's dashboard stopped before rendering with `SyntaxError: ... does not provide an export named 'useSyncExternalStore'`. The store setup form had switched to deep imports into `@spree/dashboard-ui` and `@spree/dashboard-core`, which makes Vite handle Base UI in a way that leaves one of its dependencies unconverted. The form uses the package entry points again. Base UI returns to 1.8.0; the 1.5.0 pin in the previous release did not help.
