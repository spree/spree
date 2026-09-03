---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
"@spree/dashboard-core": minor
---

Rebuild the dashboard home screen as a Pulse-style reporting overview powered by the new semantic reporting contract. `@spree/admin-sdk` adds `reporting.query()` (`POST /reporting/query` — registered metrics/dimensions, filters, time ranges, `compare: "previous_period"`, sort/limit) and `reporting.schema()` for registry introspection, plus `dashboard.operations()` for point-in-time counts (orders to fulfill, payments to collect, open returns, low/out-of-stock variants). The home screen renders five KPI tiles with trend deltas (growth is `null` when there is no previous-period baseline — shown as "New"), a current-vs-previous comparison chart, an operations card that deep-links into pre-filtered order and product lists, a rankings card with customer/category tabs, a top-products table with per-product trends, and a channel switcher defaulting to "All channels" — every widget is a reporting query sharing one time-range + channel scope. Money metrics arrive with formatted `display` strings; lookup dimensions (product, customer, category, channel) arrive hydrated as `{ id, label, meta }` with prefixed ids and product thumbnails.
