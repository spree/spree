---
"@spree/cli": minor
---

Add `spree exec`, `spree rails`, `spree bundle`, `spree rake`, and `spree task` as generic passthrough commands so any Rails / bundler / rake invocation is reachable through `spree` without `docker compose exec` incantations. `spree task <name>` auto-prefixes `spree:` to save the namespace prefix on the common path. `spree console` is rewired onto the same helper.
