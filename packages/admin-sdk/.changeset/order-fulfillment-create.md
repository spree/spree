---
"@spree/admin-sdk": minor
---

Add `orders.fulfillments.create` for manually registering fulfillments on completed orders (`POST /orders/:order_id/fulfillments`). Supports external carrier / 3PL sync: pick the stock location, carrier (`delivery_method_id`), tracking number, and line item quantities (`items`, omitted = everything not yet shipped), and pass `status: 'shipped'` to register an already-shipped fulfillment. Adds the `FulfillmentCreateParams` type. `FulfillmentUpdateParams.selected_delivery_rate_id` is now honored by the Admin API (previously the server expected a different field name and ignored it).
