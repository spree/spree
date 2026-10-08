---
"@spree/cli": patch
---

Dashboards and seller panels added with `spree add` now pass `typecheck` and `lint` out of the box: the seller panel no longer type-checks its Vite config without Node types, and the generated `biome.json` is formatted the way Biome expects.
