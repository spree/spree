---
"@spree/sdk": minor
---

Unified cart and checkout under single `carts` resource

**Breaking changes:**
- Removed `client.cart` (singular) and `client.checkout` namespaces
- All cart and checkout operations are now under `client.carts`
- All operations on a specific cart now require `cartId` as the first argument
- `UpdateCheckoutParams` renamed to `UpdateCartParams` (backward-compat alias kept)

**Migration guide:**
```typescript
// Before (0.9.x)
client.cart.create()
client.cart.get(options)
client.cart.items.create(params, options)
client.checkout.update(params, options)
client.checkout.complete(options)
client.checkout.shipments.list(options)
client.checkout.payments.create(params, options)
client.checkout.paymentSessions.create(params, options)

// After (0.10.0)
client.carts.create()
client.carts.get(cartId, options)
client.carts.items.create(cartId, params, options)
client.carts.update(cartId, params, options)
client.carts.complete(cartId, options)
client.carts.shipments.list(cartId, options)
client.carts.payments.create(cartId, params, options)
client.carts.paymentSessions.create(cartId, params, options)
```
