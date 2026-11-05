---
"@spree/cli": patch
---

`spree sdk generate` now handles three endpoint shapes it got wrong. A path nested under a resource the extension doesn't serve itself, such as `POST /carts/{cart_id}/quote_attachments`, gets a namespace of its own (`quoteAttachments.create(cartId, …)`) instead of `carts`, which the SDK already has and `extend` would refuse. A response whose schema is declared inline, such as `{ data: [...] }`, is typed from that schema as `<Namespace><Method>Response` instead of as the resource's record. And `x-spree-sdk-method` and `x-spree-sdk-namespace` (`sdk_method` in an rswag spec) name a method and its namespace without an `operationId`, which also names the operation's agent tool.
