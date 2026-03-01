---
"@spree/next": patch
---

Added automatic localization. Data functions now auto-read locale and country from cookies when no explicit options are provided. New exports: `setLocale` server action for country/language switchers, `createSpreeMiddleware` (from `@spree/next/middleware`) for URL-based routing with geo-detection. Added `country` to `SpreeNextOptions` and `countryCookieName`, `localeCookieName`, `defaultCountry` to `SpreeNextConfig`.
