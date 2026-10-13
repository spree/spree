---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/dashboard": patch
---

Added the `LocaleCode` type: the locale codes Spree accepts (every ISO 639-1 language plus regional variants such as `en-US` and `pt-BR`). Order, cart and market locales, the store's default, supported and available locales, and the matching request params now use it. The dashboard validates locale fields with the new `localeCodeSchema`.
