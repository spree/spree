---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/seller-dashboard": minor
---

Added `<resource>.form_fields` slots to the create and edit sheets for markets, stock locations, tax rates, tax categories, sales channels, policies, package types, product types, delivery zones, delivery methods, option types and customer groups. Fields a widget binds there save with the sheet. The seller panel's stock location and package type sheets use `seller.stock_location.form_fields` and `seller.package_type.form_fields`. `HostFormSlot` renders a slot that exposes a form which isn't wrapped in `FormProvider`.
