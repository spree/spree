---
"create-spree-app": minor
"@spree/cli": patch
---

Made the marketplace seller panel optional: `create-spree-app` now asks whether to install it (yes by default) and accepts `--no-seller-dashboard`. Added `--no-dashboard` for projects that are happy with the built-in admin dashboard; `--react-dashboard` is deprecated and does nothing. Apps are now set up in a consistent order — dashboard, seller panel, then storefront — and the storefront step looks the same as the others. `spree init` also installs the seller panel's dependencies, and both tools now point projects without their own dashboard at the built-in one instead of saying no admin is installed.
