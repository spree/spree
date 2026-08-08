---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Edit the admin profile in a dialog opened from the user menu instead of a settings page. The `/settings/profile` route is removed; `TopBar` takes an `onEditProfile` handler and hides the menu item when none is supplied.
