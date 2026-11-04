---
"@spree/cli": patch
---

Added `spree sdk types`, which writes the request body and list filter types for a package that extends Spree's SDKs, from the `openapi/*.yaml` documents its extension generates. The files import shared types from the SDK each document's API belongs to.
