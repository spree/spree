---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Added typed webhook events. `@spree/sdk/webhooks` now maps every event Spree publishes to the record its `data` carries, so checking `event.name` narrows `event.data`, and `constructWebhookEvent` verifies a request and returns the typed event (optionally validated with `webhookEventSchemas` from `@spree/sdk/zod`). `WebhookEvent<Order>` keeps working but is deprecated in favour of `WebhookEvent<'order.placed'>`. The Admin SDK adds `client.webhookEvents.list()`, and the dashboard's webhook event picker now reads that list instead of a hand-kept one.
