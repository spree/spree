---
"@spree/admin-sdk": minor
---

Expose customer group membership on the Customer resource. `Customer.customer_group_ids` now always returns the prefixed group IDs a customer belongs to (the full `customer_groups` objects remain available via `expand`), and `CustomerCreateParams`/`CustomerUpdateParams` accept `customer_group_ids` to replace a customer's group membership in a single `PATCH /customers/{id}` — no separate add/remove calls needed.
