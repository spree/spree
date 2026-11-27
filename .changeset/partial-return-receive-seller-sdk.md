---
"@spree/seller-sdk": patch
---

Return and exchange line items carry `resellable_quantity`, the received units that went back into stock. `orders.returns.receive()` and `orders.exchanges.receive()` take a line more than once to receive part of it as resellable and part not, and can be called again to receive units that arrive later.
