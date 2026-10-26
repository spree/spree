---
"@spree/cli": patch
---

`spree upgrade`, `spree db:reset` and `spree db:console` now say plainly when Docker is not running, and show Docker's own error for other failures instead of the command that failed.
