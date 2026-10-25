---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

A delivery method's amount for the store's default currency is now saved with its other currencies, so leaving it blank means the method isn't offered in that currency, as the form says. Before, a blank default currency was saved as free. The admin dashboard and the seller panel share one per-currency amount editor, `CurrencyAmountsField` in `@spree/dashboard-core`, so sellers can price a method in every currency the marketplace sells in. Both forms ask for an amount in at least one currency.
