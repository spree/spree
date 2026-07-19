# @spree/dashboard-core

## 0.10.2

### Patch Changes

- Fix the collapsed icon sidebar leaking a nav item's label when the item carries a badge. The collapse rule hid only the last `span` of the menu button, and a trailing badge took that slot — the label stayed visible and wrapped, breaking the collapsed layout. Both the label and badge are now hidden explicitly in collapsed icon mode.
