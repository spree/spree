---
"@spree/dashboard-core": patch
---

Fix: The dashboard and the seller panel no longer crash while the browser translates the page. Google Translate (Chrome, the Google app on iOS, Edge) replaces the text React rendered, and the next change on the page — ticking a checkbox, opening a menu — threw `NotFoundError: The object can not be found here` and showed the error screen. Removing or inserting next to a node a translator has moved now leaves the page running; pages that are not being translated are unaffected.
