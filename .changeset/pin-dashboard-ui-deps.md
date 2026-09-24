---
"@spree/dashboard-ui": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Pinned every `@spree/dashboard-ui` dependency to an exact version.

The package ships source rather than a bundle, so its dependencies are compiled into each consuming app by that app's own Vite. A floating range means a scaffolded project installs whatever those packages published most recently, not what Spree built and tested against — which is how a Base UI release that had never been tested here reached users and stopped the dashboard from starting.

`recharts` moves to 3.10.1 as part of this: 3.8.1 pinned `reselect` 5.1.1, which published without the provenance its predecessors had, so the workspace's `no-downgrade` trust policy refuses it. 3.10.1 resolves `reselect` 5.2.0, which carries provenance again. `react-redux` is overridden to 9.3.0 for the same reason — 9.2.0 dropped the provenance 9.1.0 had, and recharts' own range accepts 9.3.0.

Every other pin records the version already installed, so nothing else about the tree changes.
