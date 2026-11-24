---
"@spree/admin-sdk": patch
---

`auth.setupCountries()` now returns `Country` objects: read the country code from `iso` instead of `code`. `currency` and `locales` are unchanged, and every `Country` the Admin API returns now carries them. The `SetupCountry` type is removed; use `Country`.

`webhookEvents.list()` returns the standard pagination `meta` (`page`, `limit`, `count`, `pages` and the rest) instead of `{ count }` alone. It still returns every event unless you pass `limit`.

`TranslatableResource` and `TranslationCoverage` are now generated from the API's serializers. Their shape is unchanged, except that a translatable field's `type` is typed `string`.
