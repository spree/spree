---
"@spree/admin-sdk": minor
---

Expose `Store.available_locales` — the full canonical set of locale codes a merchant may translate content into, independent of the store's currently-configured `supported_locales`. Lets locale pickers offer any supported locale instead of only ones already in use.
