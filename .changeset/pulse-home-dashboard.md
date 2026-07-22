---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Rebuild the dashboard home screen as a Pulse-style reporting overview. The analytics endpoint now compares every KPI against the preceding period of equal length — the summary gains `units_sold` and `customers_count` (with growth rates, `null` when there is no previous-period baseline), `chart_data` carries the previous period day-by-day for a comparison overlay, and each top product reports its revenue growth. `@spree/admin-sdk` adds `dashboard.rankings()` (top customers and categories by revenue) and `dashboard.operations()` (orders to fulfill, payments to collect, open returns, low/out-of-stock variant counts). The home screen renders five KPI tiles with trend deltas, a current-vs-previous chart, an operations card that deep-links into pre-filtered order and product lists, a rankings card with customer/category tabs, and a top-products table with per-product trends.
