---
'@spree/dashboard-core': patch
---

Fix an endless reload when a store sets a non-English admin language.

i18next was initialized with the stored language but only the English bundle, so it resolved the language to the fallback and reported English no matter what was stored. The store-default reconciler compares those two values to decide whether the page needs reloading, saw a permanent mismatch, and reloaded on every boot — each reload rotating a refresh token until the API's rate limit stopped it.

Every bundle is now registered when i18next starts, so the stored language resolves to itself and the reconciler reloads only when the language genuinely changes.
