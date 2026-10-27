---
"@spree/cli": patch
---

When Docker runs out of network addresses, `spree init`, `spree dev` and the other commands that start containers now explain why and suggest `docker network prune`, instead of showing only the raw Docker error.
