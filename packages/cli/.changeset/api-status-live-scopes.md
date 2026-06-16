---
"@spree/cli": patch
---

`spree api status` now shows the API key's live scopes fetched from the server instead of the stale snapshot saved at mint time. Falls back to the local snapshot (clearly labelled) when the server can't report scopes.
