---
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": minor
"@spree/seller-dashboard": minor
---

Changed preferences to a typed contract. Every `/…/types` entry returns `schema`, the JSON Schema of the type's `preferences`, instead of `preference_schema`, and rows no longer repeat it; `PreferenceField` and `DeliveryPreferenceField` are replaced by `PreferenceSchema`. Each configurable family's settings are typed per `type` (`PromotionRulePreferencesMap`, `TypedPromotionRule`, …), and an extension adds its own by declaration merging. Store, channel, import and seller profile settings drop the `preferred_` prefix (`guest_checkout`, `timezone`, `delimiter`), the store's decimal settings are strings, and delivery methods read and write `calculator: { type, preferences }`. Preference writes are validated, refused with `invalid_preferences` and a JSON pointer per failing value. `paymentMethods.types()` lists every provider with `installed` set on those the store already has.
