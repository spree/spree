---
"@spree/cli": patch
---

`spree init` no longer stops when pulling the latest images fails, for example on Docker Hub's anonymous rate limit or without network. It starts the images already on the machine; only an image that was never pulled still fails.
