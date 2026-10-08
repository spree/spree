---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Money fields are now shown and read in the number format of the person using the dashboard, whatever the currency or market: an admin whose dashboard is in German types `1.234,56` for dollars and euros alike. Previously the format followed the currency's market, which was ambiguous when two markets shared a currency. `useFormCurrencyLocale` and the panel client's `markets` entry are removed; use `useMoneyLocale()`.
