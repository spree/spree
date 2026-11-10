---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
---

Refreshed the look of the admin dashboard and the seller panel: the Inter font, one 13px text size, a neutral palette with 12px corners and a near-black dark theme. Fields, cards, switches, tabs and alerts share one style, list tables lose their frame and gain a compact row density, and date filters use a range calendar. Records on detail pages sit under titled sections instead of cards nested in cards, and the settings nav sits beside the icon rail.

For plugin authors, `@spree/dashboard-ui` adds `Section`, `StatItem`, `ProductIdentity`, `CurrencyLabel`, `DateRangePanel` and new icons, and `@spree/dashboard-core` adds `useTableDensity`. The card `variant` prop is deprecated and has no effect: group records under a `Section` instead.
