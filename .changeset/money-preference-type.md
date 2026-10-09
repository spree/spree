---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/admin-sdk": patch
---

Preferences of the new `money` type are shown with their currency's symbol in settings forms and as money in calculator summaries, instead of being guessed from the preference's name. `PreferenceField.type` documents the `money` type.
