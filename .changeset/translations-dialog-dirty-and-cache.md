---
'@spree/dashboard': patch
'@spree/dashboard-ui': patch
'@spree/dashboard-core': patch
---

Stop the translations editor marking itself dirty on open, and refresh the translations page after a save or a catalog edit.

The rich-text cell was treating TipTap's mount-time paragraph wrap as an unsaved change against descriptions stored as plain text. Translation queries now share one cache prefix so saving a translation, editing the source record, or importing a translations CSV invalidates the coverage grid instead of leaving it stale.
