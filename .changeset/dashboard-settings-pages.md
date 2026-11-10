---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

Payment methods became a Payments page: payment providers with their logos and status, manual payment methods, a Checkout order sheet for the order checkout offers them in, and the payment capture setting. Bogus is marked as a test gateway. Tax by shipping address moved to the Taxes page, and a new Storefront & checkout page holds the storefront URL, storefront access, checkout and address settings that used to be on the store page. Settings pages show a label beside its control on desktop, and the store timezone is a searchable picker.

`@spree/dashboard-core` adds `SettingsContainer`, `SettingsFieldGroup`, `SettingsRow`, `SettingsSelectField`, `SettingsSwitchField` and `TimezoneCombobox`, and `SettingsSection` takes an `icon`. The payment methods list table (`payment-methods`) is gone, so columns a plugin added to it no longer show.
