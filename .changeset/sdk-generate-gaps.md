---
"@spree/cli": patch
---

`spree sdk generate` now types a response whose schema is declared inline, such as `{ data: [...] }`, from that schema, as `<Namespace><Method>Response`, instead of as the resource's record; a list declared that way is not wrapped in `PaginatedResponse` again. `x-spree-sdk-method` and `x-spree-sdk-namespace` (`sdk_method` in an rswag spec) name a method and its namespace without an `operationId`, which also names the operation's agent tool, so a path nested under one of the SDK's resources, such as `/carts/{cart_id}/quote_attachments`, can go in a namespace of the extension's own instead of `carts`, which `extend` refuses. A namespace that is not an identifier, and two inline response types of one name, are refused with the path to fix instead of writing a client that does not compile.
