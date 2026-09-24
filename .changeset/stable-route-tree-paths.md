---
"@spree/dashboard-core": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
"@spree/cli": patch
---

Fixed the setup screen of a new project reloading while the merchant was filling it in. The generated route file now refers to installed packages by their stable location, and `spree add` generates it right after installing, so the first dev start has nothing to rewrite. Upgrades also no longer rewrite every line of that file, so its diff shows only the pages an upgrade added.
