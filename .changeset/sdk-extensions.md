---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Added `client.extend()` and `defineStoreExtension`, `defineAdminExtension` and `defineSellerExtension`, so a package can add a typed namespace for an extension's own endpoints to a client, such as `client.quotes`. The extension calls through the client's own request function, so it shares the client's auth, store or seller, locale defaults and retries; `extend` returns a new client and refuses a name the client already has. An extension's `build` also gets `listParams` and `readParams`, which build list and read queries the way the built-in methods do, and each SDK now exports the `Extension` and `RequestFn` types its published declarations reference.
