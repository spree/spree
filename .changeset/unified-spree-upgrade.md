---
"@spree/cli": minor
"create-spree-app": patch
---

Merged `spree update` into `spree upgrade`, which now upgrades both prebuilt-image and ejected projects and also updates the `@spree/*` packages of the project root and the dashboard apps. `spree update` keeps working for one release with a deprecation warning. New projects get an `upgrade` script instead of `update`.
